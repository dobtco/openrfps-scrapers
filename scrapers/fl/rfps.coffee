###
Schema items not provided are marked x below:
	id 	A unique identifier string
 	type 	The type of posting, e.g. RFP or RFI. 
	html_url 	A link to the RFP page
	title 	Title
 x	department_name 	Department name
 	address 	Full address related to this RFP (will be normalized later)
 	awarded 	Boolean - has the RFP been awarded? (Leave blank for unknown)
 x	canceled 	Boolean - has the RFP been canceled? (Leave blank for unknown)
 	contact_name 	Contact name
 	contact_phone 	Contact phone
 	contact_fax 	Contact fax
 	contact_email 	Contact email
 	created_at 	When was this RFP posted?
 	updated_at 	When was this RFP revised?
 x	responses_open_at 	When do responses open?
 	responses_due_at 	When are responses due?
 	description 	Text/HTML description
 x	prebid_conferences 	Array of Conference objects
 	downloads 	Array of file URLs
 	nigp_codes 	Array of NIGP codes
 x	commodity 	String representing the commodity (we'll try to match it to a code)
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
TYPE_TYPES = # based on "Ad Type" in list or 2nd text line in detail screen
  Competitive_Solicitation: 'ITB'           # Invitation to bid
  Invitation_to_Negotiate: 'RFP'            # Request for proposal
  Request_for_Proposal: 'RFP'               # Request for proposal
  Invitation_to_Bid: 'ITB'                  # Invitation to bid
  Agency_Decisions: 'XXX'                   # Closed proposals
  Single_Source: 'XXX'                      # Closed proposals
#  Some_string_maybe: 'RFQ'                  # Request for quotes
  Informational_Notice: 'RFP'               # Request for proposal
  Request_for_Information: 'RFI'            # Request for information
  Public_Meeting_Notice: 'RFP'              # Request for proposal
  Single_Source_Announcements_Awards: 'XXX' # Closed proposals

MISC_PARAMS =    # Note sequence here must match sequence in html!!!
#  id2:              'Advertisement Number:' # Redundant already got from list
  version_nr:       'Version Number:'
  created_at:       'Advertisement Begin Date/Time:'
  responses_due_at: 'Advertisement End Date/Time:'
  updated_at:       'Last Edit:'
  contact_name:     'Please direct all questions to:'
  contact_phone:    'Phone:'   
  contact_fax:      'FAX:'  
  contact_email:    'Email:'

EDIT_LENGTHS =
#  id2:              30
  version_nr:        3
  created_at:       45
  responses_due_at: 45
  updated_at:       45
#  contact_name:     45
  contact_phone:    14  
  contact_fax:      14  
  contact_email:    50

BASE_URL = 'http://www.myflorida.com'
WANT_URL = '/apps/vbs/vbs_www.search_r1.matching_ads_page'
DOWNLOAD_URL = "/apps/vbs/vbs_pdf.download_file?p_file="
ASYNC_RQ_MAX = 5

# We'll export one function, that takes two parameters: an options hash,
# and a callback that must be executed once we're done scraping.
module.exports = (opts, done) ->

  # Set up an empty array for our RFPs.
  rfps = []

  unless opts.limit
    opts.limit = 9999

  request.get("#{BASE_URL}#{WANT_URL}", (err, response, html) ->

    # Load the resulting HTML into Cheerio
    $ = cheerio.load html

    $("#OutTable").children( 'tr' ).slice(1,opts.limit+1).each (i, el) -> 
      rfps.push {
        id:   $(@).find("td").eq(1).text().trim()
        type: TYPE_TYPES[$(@).find("td").eq(3).text().trim().replace /[\s]/g, '_']
        title: $(@).find("td").eq(0).text().trim()
        version: $(@).find("td").eq(2).text().trim()
        html_url: "#{BASE_URL}#{$(@).find('a').attr('href').trim()}"
        end_date: $(@).find("td").eq(4).text().trim()}

    # Make up to ASYNC_RQ_MAX concurrent requests to the procurement site.
    # We call the getRfpDetails() function for each one.
    # Callback the done() function passed in the `module.exports` call.
    async.eachLimit rfps, ASYNC_RQ_MAX, getRfpDetails, (err) ->
      console.log(err.red) if err

      done rfps
  )
 
  # A function for scraping the details from an RFP page.
  getRfpDetails = (item, cb) ->

    if item.type is TYPE_TYPES.Agency_Decisions
      item.awarded = true
      item.type = TYPE_TYPES.Request_for_Proposal

    # GET request for the RPF details: load the html response into Cheerio
    request.get item.html_url, (err, response, body) ->
      $ = cheerio.load body

      offset = []
      item.address = []
      item.downloads = []
      item.nigp_codes = []

      $tr = $('body').children('table').eq(0).children('tr').eq(1)
      $b = $tr.find('b')

      # Most data items are in freely formatted text, so we search
      # for their locations using their labels, then truncate the found 
      # text to an appropriate length
      loc = 0
      for k, v of MISC_PARAMS
        loc = v.length + 1 + $tr.text().indexOf v, loc
        item[k] = $tr.text()
          .substring loc, loc+300
          .trim()
        offset[k] = loc

      # Contact address has no label, but follows the phone &/or fax number(s)
      if item.contact_fax isnt ''
        address = item.contact_fax
      else
        address = item.contact_phone
      sss = ((address.split 'Email')[0].substring 20).split '\n'
      lll = [0..sss.length-1]
      sss[k] = sss[k].trim() for k in lll
      (item.address.push sss[k] if sss[k].length > 0) for k in lll   
      item.contact_name = (item.contact_name.split '\n')[0].trim()
      item.contact_email = (item.contact_email.split '\n')[0].trim()

      item.agency = $b.eq(4).text().trim() 

      # Type text is more granular on the detail page so recompute it
      item.type = TYPE_TYPES[$b.eq(5).text().trim().replace /[\s\/]/g, '_']
      if item.type is TYPE_TYPES.Agency_Decisions
        item.awarded = true
        item.type = TYPE_TYPES.Request_for_Proposal

      last_nigp_code = ''
      $tr.find('table')
        .eq(1)
        .find('tr[valign="top"]')
        .each (i, el) ->
          last_nigp_code = $(@).find('td').eq(0).text().trim()
          item.nigp_codes.push last_nigp_code.replace /[\s+\-]/g, ''

      $tr.find('table:contains(Downloadable Files for Advertisement)').find('tbody')
        .find('a').each (i, el) -> (
          if DOWNLOAD_URL is $(@).attr('href').substring  0,DOWNLOAD_URL.length
            item.downloads.push BASE_URL+$(@).attr('href'))

      item.description =  # located after last NIGP code & before contact details
        ((($tr.text().substring offset.updated_at, offset.contact_name)
          .split last_nigp_code)[1]
          .split 'Please direct all questions to:')[0]
          .trim()
          .replace /\s+/g, ' ' # Adjust this if desired to retain line breaks

      for k, v of EDIT_LENGTHS
        item[k] = (item[k].substring 0, v).trim()

      cb()