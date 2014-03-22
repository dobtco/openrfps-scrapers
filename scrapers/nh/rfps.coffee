###
Schema items not provided are marked x below:
	id 	A unique identifier string
 	type 	The type of posting, e.g. RFP or RFI. 
	html_url 	A link to the RFP page
	title 	Title
 	department_name 	Department name
 x	address 	Full address related to this RFP (will be normalized later)
 	awarded 	Boolean - has the RFP been awarded? (Leave blank for unknown)
 x	canceled 	Boolean - has the RFP been canceled? (Leave blank for unknown)
 	contact_name 	Contact name
 x	contact_phone 	Contact phone
 x	contact_fax 	Contact fax
 	contact_email 	Contact email
 	created_at 	When was this RFP posted?
 x	updated_at 	When was this RFP revised?
 x	responses_open_at 	When do responses open?
 	responses_due_at 	When are responses due?
 x	description 	Text/HTML description
 x	prebid_conferences 	Array of Conference objects
 	downloads 	Array of file URLs
 x	nigp_codes 	Array of NIGP codes
 	commodity 	String representing the commodity (we'll try to match it to a code)
 x	estimate 	Estimated cost of the contract
 x	duration 	Duration of contract
###

# Require the necessary modules.
request = require 'request'
cheerio = require 'cheerio'
async = require 'async'
_ = require 'underscore'
require 'colors'

# Set up some constants that we'll use later.

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
    $('body').find('table').eq(3).find('tr').slice(2,opts.limit+2).each( (i, el) ->
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