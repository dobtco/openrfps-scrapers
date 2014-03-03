# Require the necessary modules.
request = require 'request'
cheerio = require 'cheerio'
async = require 'async'
_ = require 'underscore'
require 'colors'

# Set up some constants that we'll use later.
FILTER_PARAMS =
  track: ''
  bidResponse: 'all'
  theType: 'OPEN'
  govType: 'state'
  theAgency: 'all'
  theWord: ''
  theSort: 'BID NUMBER'

BASIC_PARAMS =
  department_name:   'Agency:'
  estimate:          'Previous Price Paid'
  responses_open_at: 'Solicitation type'

CONTACT_PARAMS =
  contact_email:     'Email:'
  contact_phone:     'Phone:'
  contact_fax:       'Fax:'
  contact_name:      'Contact Name:'

UPDATE_PARAMS =
  created_at:        'Upload Date:'
  updated_at:        'Updated date:'

BASE_URL = 'http://esbd.cpa.state.tx.us'
ASYNC_RQ_MAX = 5

# Schema items not provided:
# responses_open_at - currently filled with the "Solicitation type"
# awarded
# canceled
# prebid_conferences
# commodity
# duration

rfps = [];

# We'll export one function, that takes two parameters: an options hash,
# and a callback that must be executed once we're done scraping.
module.exports = (opts, done) ->

  # Set up an empty array for our RFPs.
  rfps = [];

  # Specify the rows we want by putting row values in the url
  # If not specified, it returns records in sets of 25
  unless opts.limit
    opts.limit = 25
  wanturl = "#{BASE_URL}/newbidshow.cfm?startrow=1&endrow=#{opts.limit}"

  # Send a GET request to the site's endpoint
  request.get(wanturl, (err, response, html) ->

    # Load the resulting HTML into Cheerio
    $ = cheerio.load html

    # The html gives 1 table per RPF plus a final empty table
    # Note the id is initially blank for the 1st row only
    # but this is corrected in the details retrieval function
    $('table').each( (i, el) -> rfps.push {
        id:        $(@).find("tr:contains(Req. Number:)").find('a').text().trim(),
        html_url: "#{BASE_URL}/#{$(@).find('a').attr('href')}",
        title:    ($(@).find('td').eq(0).text().split ':')[1]});

    # Truncate the final bogus entry from the array (Always!)
    rfps = _.first(rfps, rfps.length-1)

    # Truncate the array to include only the requested number of RFPs
    rfps = _.first(rfps, opts.limit)

    # Make up to ASYNC_RQ_MAX concurrent requests to the procurement site.
    # We call the getRfpDetails() function for each one.
    # Callback the done() function passed in the `module.exports` call.
    async.eachLimit rfps, ASYNC_RQ_MAX, getRfpDetails, (err) ->
      console.log(err.red) if err
      done rfps
    );

  # A function for scraping the details from an RFP page.
  getRfpDetails = (item, cb) ->

    # GET request for the RPF details: load the html response into Cheerio
    request.get item.html_url, (err, response, body) ->
      $ = cheerio.load body

      # Contact info is all in one identifiable table
      $cTable = $('table:contains(Contact Information:)')

      for k, v of CONTACT_PARAMS
        item[k] = $cTable.find("tr:contains(#{v})")
          .find('td')
          .eq(1)
          .text()
          .trim()

      item.contact_name = item.contact_name.replace /\s+/g, ' '

      # Address has several lines, produced here in an array
      # as it is not clear if the number of lines in the html can vary.
      # The 1st line is labeled 'Address:', the others are unlabeled, so have no ':'
      item.address = []
      $cTable.find('tr').each((i, el) ->
        aLine = (($(@).find('td').eq(0).text().indexOf 'Address:') is 0 or
                        ($(@).find('td').eq(0).text().indexOf ':') is -1)
        item.address.push $(@).find('td').eq(1).text() if aLine);

      for k, v of BASIC_PARAMS
        item[k] = ($("tr:contains(#{v})")
          .find('td')
          .text()
          .split ':')[1]
          .trim()

      item.id = ($('td:contains(Agency Requisition Number:)')
        .eq(1)
        .text()
        .split ':')[1]
        .trim()

      item.responses_due_at = ($('td:contains(Open Date:)')
        .text()
        .split ': ')[1]
        .trim()

      item.responses_due_at = (item.responses_due_at.split 'Agency')[0].trim()
      item.title = $('table').find('td').eq(0).text().trim()

      # The colspan seems an unreliable way to find the data but there is no label
      item.description = $('td[colspan=2]').find('td').eq(0).text()

      # Create / update dates hang out in untagged text at the bottom of the page
      loc = 0
      for k, v of UPDATE_PARAMS
        loc = v.length + 1 + $('div[id="mainbody"]').text().indexOf v, loc
        item[k] = $('div[id="mainbody"]')
          .text()
          .substring loc, loc+19      # Truncates fractions of a second

      item.nigp_codes = []
      $('td:contains(Class-Item)').each((i, el) ->
        item.nigp_codes.push ($(@).text().split ':')[1].trim().replace /[\s+\-]/g, '')

      item.downloads = []
      $('a:contains(Package)').each (i, el) ->
        item.downloads.push BASE_URL+$(@).attr('href')

      item.type = 'RFP' # Assuming that everything is an RFP for now.

      cb()