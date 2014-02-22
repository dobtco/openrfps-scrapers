# Require the necessary modules.
request = require 'request'
cheerio = require 'cheerio'
async = require 'async'
_ = require 'underscore'
require 'colors'

module.exports = (opts, done) ->

  rfps = []
  numPages = undefined
  request = request.defaults(jar: true)

  getPage = (x, cb) ->
    console.log "requesting page #{x}"

    request.post "http://camisvr.co.la.ca.us/lacobids/BidLookUp/BLView.asp",
      form:
        HiddenCurrPage:x
        sType:'A'
        SortType:'A'
        BL:null
        SSearch:null
        SText:null
        selpage:1
    , (err, response, body) ->
      $ = cheerio.load body

      $('table').eq(0).find('tr').each ->
        if $(@).find('td').length > 0
          rfps.push {
            id: $(@).find('td').eq(0).text()
            alt_id: $(@).find('td').eq(0).find('a').attr('href').match(/\d+/)[0]
          }

      cb()

  getPages = (cb) ->
    async.eachLimit [1..numPages], 1, getPage, (err) ->
      console.log(err.red) if err
      cb()

  getDetail = (item, cb) ->
    console.log "Getting details for #{item.alt_id}..."
    request.post "http://camisvr.co.la.ca.us/lacobids/BidLookUp/BidDesc.asp",
      form:
        HiddenBID: item.alt_id
    , (err, response, body) ->
      console.log "Received details for #{item.alt_id}...".green
      $ = cheerio.load body

      attrs =
        title: 'Bid Title'
        department_name: 'Department'
        responses_open_at: 'Open Date'
        responses_due_at: 'Closing Date'
        updated_at: 'Last Changed On'
        contact_email: 'Contact Email'
        contact_phone: 'Contact Phone'
        contact_name: 'Contact Name'
        commodity: 'Commodity'

      for k, v of attrs
        item[k] = $('table').eq(0).find("td:contains(#{v})").next('td').text()

      cb()

  getDetails = (cb) ->
    if opts.limit > 0
      rfps = _.first(rfps, opts.limit)

    async.eachLimit rfps, 1, getDetail, (err) ->
      console.log(err.red) if err
      cb()

  console.log "Getting index and setting session..."
  request.get "http://camisvr.co.la.ca.us/lacobids/BidLookUp/BLView.asp", (err, response, body) ->
    console.log "Received.".green
    $ = cheerio.load body
    numPages = parseInt($('body').text().match(/Page 1 of ([0-9]+)/)[1], 10)

    if opts.limit > 0
      numPages = Math.ceil(opts.limit / 12) # 12 per page

    getPages ->
      getDetails ->
        done(rfps)
