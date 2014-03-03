xml2js = require 'xml2js'
request = require 'request'
cheerio = require 'cheerio'
async = require 'async'
_ = require 'underscore'
require 'colors'

BASIC_PARAMS =
  title: 'Bid Title:'
  contact_name: 'Name:'
  contact_phone: 'Phone:'
  contact_email: 'E-mail:'
  contact_fax: 'Fax:'
  id: 'Bid Number:'
  department_name: 'Agency:'
  commodity: 'Bid Type:'
  estimate: 'Estimated Cost:'
  duration: 'Duration:'

module.exports = (opts, done) ->

  rfps = []

  # Send a GET request to grab the RSS feed of Bids/Contracts
  request.get 'http://mission.sfgov.org/OCABidPublication/rss.aspx', (error, response, body) ->

    # Load the RSS string into xml2js to turn xml to nicer js objects
    parser = new xml2js.Parser()
    parser.parseString body, (err, result) ->
      items = result.rss.channel[0].item
      _.each items, (v, k, list) ->
        rfps.push html_url: v.link[0]

    # If the user wants to limit the number of results, use Underscore's _.first to do the job
    if opts.limit > 0
      rfps = _.first(rfps, opts.limit)

    # Asynchronously loop through all of the RFPs 5 at a time
    async.eachLimit rfps, 5, getRfpDetails, (err) ->
      console.log(err.red) if err
      done rfps

  getRfpDetails = (item, cb) ->
    request.get item.html_url, (err, response, body) ->
      $ = cheerio.load body
      $bid_details = $('#_ctl0_cp_BODY_CONTENT_BidDetailBody_PANEL_BID_DETAILS')

      for k, v of BASIC_PARAMS
        item[k] = $bid_details.find("tr:contains(#{v})").find('td').eq(1).text().trim()

      item.responses_due_at = $bid_details.find("tr:contains(Bid Due:)").find('td').eq(1).text().trim() + " " + $bid_details.find("tr:contains(Time Due:)").find('td').eq(1).text().trim()
      item.description = $('#_ctl0_cp_BODY_CONTENT_BidDetailBody_lbl_DESCRIPTION').text().trim()

      if $('body').text().match /pre-bid/i
        item.prebid_conferences = []
        item.prebid_conferences.push {
          attendance_mandatory: false
          datetime: $bid_details.find('tr:contains(Date:)').find('td').eq(1).text().trim() + " " + $bid_details.find('tr:contains(Time:)').find('td').eq(1).text().trim()
          address: $bid_details.find('tr:contains(Location:)').find('td').eq(1).text().trim()
        }
        # Whether or not the prebid conference is mandatory is stored in the address field.
        # The following checks for mandatory, sets the flag accordingly
        # I would remove the text, but there are so many variations, it may be easier to handle
        # when parsing the address field
        mandatory = item.prebid_conferences[0].address.match /mandatory/
        item.prebid_conferences[0].attendance_mandatory = true if mandatory unless item.prebid_conferences[0].address.match /not mandatory/
        if mandatory
          item.prebid_conferences[0].address = item.prebid_conferences[0].address.split('mandatory')[1]

      # Not very good QA on this list of bids, some have no unique id, and there is at
      # least one duplicate project in the current list. There seems to be no consistent
      # bid number across the City, so to avoid conflicts, I'm appending the ID to the
      # record in the database that gets passed in the query string. This is the only
      # number I can have a reasonable expectation will always be unique.
      item.id = item.id + "-" + item.html_url.substring(item.html_url.indexOf("?K=") + 3)

      item.downloads = []
      $('tr:contains(download files:)').next().find('a').each ->
        item.downloads.push "http://mission.sfgov.org" + $(@).attr('href')

      item.type = if item.id.match 'RFQ'
        'RFQ'
      else
        'RFP'

      console.log "Successfully downloaded #{item.title}".green
      cb()
