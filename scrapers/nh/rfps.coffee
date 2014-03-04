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

# Schema items not provided:
#  address            Full address related to this RFP (will be normalized later)
#  canceled           Boolean - has the RFP been canceled? (Leave blank for unknown)
#  contact_phone      Contact phone
#  contact_fax        Contact fax
#  updated_at         When was this RFP revised?
#  responses_open_at  When do responses open?
#  description 	      Text/HTML description
#  prebid_conferences Array of Conference objects
#  nigp_codes         Array of NIGP codes
#  estimate           Estimated cost of the contract
#  duration           Duration of contract

# Could source any of the following from detail by uncommenting the relevant line
# Marked with ** if conceptually available from detail screen but not from list
BASIC_PARAMS =
  id                     : 'Request #'
  title                  : 'Description'
  description            : 'Comments' # **
#  awarded                : 'Status'
  responses_due_at       : 'Closing Date'
#  responses_due_at_time  : 'Closing Time'
  created_at             : 'Posted Date'
#  reqtype                : 'Request Type' # **
#  contract               : 'Contract' # **
  req_nr                 : 'Requisition Number' # **
#  category               : 'Category' # **
#  agency                 : 'Agency' # **
#  mult_agencies          : 'Multiple Agencies' # **
  department_name        : 'Division' # **
  contact_name           : 'Contact'
#  downloads              : 'Addendums Referenced'
#  awarded_bids           : 'Awarded Bids' # **

LIST_PARAMS = [
  'title'
  'id'
  'downloads'
  'responses_due_at'
# 'responses_due_at_time' # this column not parsed by this mechanism
  'awarded'
  'contact_name'
  'department_name'
  'commodity'
  'created_at'
  ]

TYPES =
  Bid: 'ITB'
  RFP: 'RFP'
  RFB: 'ITB'
WANTED_COLS = [0,1,2,3,5,6,7,8,9]
BASE_URL = 'http://www.admin.state.nh.us/purchasing/'
WANT_URL = 'bids_posteddte.asp'
ASYNC_RQ_MAX = 5

rfps = [];

module.exports = (opts, done) ->

  # Set up an empty array for our RFPs.
  rfps = [];

  wanturl = BASE_URL+WANT_URL

  # Send a GET request to the site's endpoint
  request.get(wanturl, (err, response, html) ->

    # Load the resulting HTML into Cheerio
    $ = cheerio.load html
    $('body').find('table').eq(3).find('tr').each( (i, el) ->
      gobj =
      ( _.object(LIST_PARAMS,
        $(@).find('td').eq(k).text().trim() for k in WANTED_COLS))
      gobj.responses_due_at =
        "#{gobj.responses_due_at} #{$(@).find('td').eq(4).text().trim()}"
      gobj.html_url = BASE_URL+$(@).find('td').eq(1).find('a').attr('href')
      gobj.contact_email = $(@).find('td').eq(6).find('a').attr('href')
      if gobj.contact_email
        gobj.contact_email = (gobj.contact_email.split ':')[1]
      if gobj.awarded is 'Open' # Redundant: all listed items are open i.e. unawarded
        gobj.awarded = false
      if gobj.downloads
        gobj.downloads = []
        $(@).find('a:contains(Addendum)').each (i, el) ->
          gobj.downloads.push $(@).attr('href').trim().replace(/\s/g, '%20')
      else
        gobj.downloads = []
      gobj.type = TYPES[(gobj.id.substring 0,3)]
      unless gobj.type
        gobj.type = ''
      rfps.push gobj )

    rfps = _.last(rfps, rfps.length-2)  # first two rows contain headers

    async.eachLimit rfps, ASYNC_RQ_MAX, getRfpDetails, (err) ->
      console.log(err.red) if err
    done rfps
    );

  # A function for scraping the details from an RFP page.
  getRfpDetails = (item, cb) ->
    ca = []

    # GET request for the RPF details: load the html response into Cheerio
    request.get item.html_url, (err, response, body) ->
      $ = cheerio.load body
      # Find text in table area, each label precedes related value by 2 cells
      $('body').find('table').eq(4).find('td').each (i, el) ->
        ca.push $(@).text().trim()
    for k, v of BASIC_PARAMS
      unless item[k]
        item[k] = (_.object (_.first ca, ca.length-2), (_.last ca, ca.length-2) )[v]
      unless item[k]
        item[k] = ''

    cb()