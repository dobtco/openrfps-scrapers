request = require 'request'
cheerio = require 'cheerio'
async = require 'async'
YAML = require 'libyaml'
_ = require 'underscore'
require 'colors'

BASIC_PARAMS =
  id: 'BAVN ID:'
  bid_method: 'Bid Method:'
  category: 'Category:'
  type: 'Type:'
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
  rfps = []

  request.get CONFIG['index_url'], (error, response, body) ->
    $ = cheerio.load body
    links = $('table.printtable tr').find('a').filter (i, el) ->
      /opportunity_view/.test($(this).attr('href'))

    links.each (i, el) ->
      rfps.push {
        url: CONFIG['url'] + $(this).attr('href')
        title: $(this).text().trim()
      }

    console.log "Retrieved #{rfps.length} links to RFPs".green

    async.eachLimit rfps, 5, getRfpDetails, (err) ->
      console.log(err.red) if err
      done rfps

  getRfpDetails = (rfp, callback) ->
    request.get rfp.url, (err, response, body) ->
      console.log rfp.url
      $ = cheerio.load body

      for k, v of BASIC_PARAMS
        td = $("table[cellspacing=0] tr:contains(#{v}) td").eq(1)
        rfp[k] = td.text().trim()

      console.log "Downloaded RFP: #{rfp.title}".green
      callback()
