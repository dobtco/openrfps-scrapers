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
  id                     : 'Request #'
  title                  : 'Description'
  description            : 'Comments'
#  awarded                : 'Status'
  responses_due_at       : 'Closing Date'
  responses_due_at_time  : 'Closing Time'
  created_at             : 'Posted Date'
  reqtype              : 'Request Type'
  contract             : 'Contract'
  req_nr               : 'Requisition Number'
  category             : 'Category'
  agency               : 'Agency'
  mult_agencies        : 'Multiple Agencies'
  department_name        : 'Division'
  contact_name           : 'Contact'
#  downloads              : 'Addendums Referenced'
#  awarded_bids         : 'Awarded Bids'

LIST_PARAMS = [
  'title'
  'id'
  'downloads'
  'responses_due_at'
  'responses_due_at_time'
  'awarded'
  'contact_name'
  'department_name'
  'commodity'
  'created_at'
  'html_url'
  'contact_email'
  ]

BASE_URL = 'http://www.admin.state.nh.us/purchasing/'
WANT_URL = 'bids_posteddte.asp'

ASYNC_RQ_MAX = 5

#   Schema items not provided:
#	address 	Full address related to this RFP (will be normalized later)
#	canceled 	Boolean - has the RFP been canceled? (Leave blank for unknown)
#	contact_phone 	Contact phone
#	contact_fax 	Contact fax
#	updated_at 	When was this RFP revised?
#	responses_open_at 	When do responses open?
#	description 	Text/HTML description
#	prebid_conferences 	Array of Conference objects
#	nigp_codes 	Array of NIGP codes
#	estimate 	Estimated cost of the contract
#	duration 	Duration of contract

#Available at detail screen but not from list
#Comments
#Request Type
#Contract
#Requisition Number
#Category
#Agency
#Multiple Agencies
#Division
#Awarded Bids

rfps = [];

module.exports = (opts, done) ->

  # Set up an empty array for our RFPs.
  rfps = [];

  wanturl = BASE_URL+WANT_URL

  # Send a GET request to the site's endpoint
  request.get(wanturl, (err, response, html) ->

    # Load the resulting HTML into Cheerio
    $ = cheerio.load html
    garr = []    # Array for contents of cells numbered across table row
    $('body').find('table').eq(3).find('tr').each( (i, el) ->
      garr = ( $(@).find('td').eq(k).text().trim() for k in [0..9] ) 
      garr[10] = BASE_URL+$(@).find('td').eq(1).find('a').attr('href')
      garr[11] = $(@).find('td').eq(6).find('a').attr('href')
      if garr[5] is 'Open'
        garr[5] = false   # All listed items are open i.e. unawarded
      if garr[11]
        garr[11] = (garr[11].split ':')[1]
      if garr[2]
        garr[2] = []
        $(@).find('a:contains(Addendum)').each (i, el) ->
          garr[2].push $(@).attr('href').trim() # .replace /[\s]/g, '%20'  #  '_' TESTING!!!
      else
        garr[2] = []
      rfps.push ( _.object(LIST_PARAMS, garr) ) )

    rfps = _.last(rfps, rfps.length-2)     

    async.eachLimit rfps, ASYNC_RQ_MAX, getRfpDetails, (err) ->                                        console.log(err.red) if err
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