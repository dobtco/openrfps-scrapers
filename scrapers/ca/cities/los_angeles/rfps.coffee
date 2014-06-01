request = require 'request'
cheerio = require 'cheerio'
async = require 'async'
YAML = require 'libyaml'
_ = require 'underscore'
Q = require 'q'
require 'colors'

BASIC_PARAMS =
  id: 'BAVN ID:'
  bid_method: 'Bid Method:'
  category: 'Category:'
  description: 'Description:'
  status: 'Status:'
  posted: 'Posted:'
  due: 'Bid Due:'
  contact_name: 'Name:'
  contact_phone: 'Phone:'
  contact_email: 'E-mail:'
  department_name: 'Dept:'
  commodity: 'Bid Type:'

module.exports = (opts, done) ->
  CONFIG = YAML.readFileSync(__dirname + '/config.yml')[0]

  request.get CONFIG['index_url'], (error, response, body) ->
    extractPageUrls(body)
    .then (pageUrls) ->
      retrievePageBodies(pageUrls)
    .then (pageBodies) ->
      pageBodies.push(body)
      extractRfps pageBodies
    .then (rfps) ->
      console.log "Retrieved #{rfps.length} links to RFPs".green

      async.eachLimit rfps, 5, rfpDetails, (err) ->
        console.log(err.red) if err
        done rfps

  extractPageUrls = (body) ->
    d = Q.defer()
    urls = []
    $ = cheerio.load body

    $('table.pagecounter a').each (i, em) ->
      urls.push $(this).attr('href')

    d.resolve urls
    d.promise

  retrievePageBodies = (pageUrls) ->
    d = Q.defer()

    async.mapSeries pageUrls, (pageUrl, callback) ->
      request.get pageUrl, (error, response, body) ->
        callback(null, body)
    , (err, results) ->
      d.resolve results

    d.promise

  extractRfps = (pageBodies, rfps) ->
    d = Q.defer()
    rfps = []

    pageBodies.map (pageBody) ->
      $ = cheerio.load pageBody
      rows = $('table.printtable tr')

      rows.each (i, el) ->
        row = $(this)
        rfp = {}

        links = row.find('a').each (i, el) ->
          url =  $(this).attr('href')
          isRfpUrl = /opportunity_view/.test url

          if isRfpUrl
            rfp.url = CONFIG['url'] + $(this).attr('href')
            rfp.title =  $(this).text().trim()
            rfp.type = row.find('td').eq(4).text().trim()
            rfps.push rfp

    d.resolve rfps
    d.promise

  rfpDetails = (rfp, callback) ->
    request.get rfp.url, (err, response, body) ->
      $ = cheerio.load body

      for k, v of BASIC_PARAMS
        td = $("table[cellspacing=0] tr:contains(#{v}) td").eq(1)
        rfp[k] = td.text().trim()

      console.log "Downloaded RFP: #{rfp.title}".green
      callback()
