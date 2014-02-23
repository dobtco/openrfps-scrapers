# Require the necessary modules.
request = require 'request'
cheerio = require 'cheerio'
async = require 'async'
_ = require 'underscore'
require 'colors'

# Set up some constants that we'll use later.

BASIC_PARAMS =
  title: 'Bid Title'
  contact_name: 'Contact Person'
  contact_phone: 'Contact Phone Number'
  contact_email: 'Contact E-mail Address'
  created_at: 'Date Posted'
  updated_at: 'Last Revision Date'
  responses_due_at: 'Bid Closing Date/Time'
  department_name: 'Agency'

DEPT_ROWS =
  department_name: 0
  section: 1
  department_code: 2
  contact_name: 3
  contact_address: 4
  contact_city: 6
  contact_email: 9
  contact_phone:7
  contact_fax: 8
  url: 5

# We'll export one function, that takes two parameters: an options hash,
# and a callback that must be executed once we're done scraping.
module.exports = (opts, done) ->

  # Set up an empty array for our RFPs.
  rfps = []

  # Send a POST request to the site's endpoint. Why we're POSTing to read data, you'll have to tell me...
  request.get 'https://www.ips.state.nc.us/IPS/catbids.aspx', (err, response, body) ->

    # Load the resulting HTML into Cheerio, a jQuery-like DOM parser.
    $ = cheerio.load body

    # State of NC begins with a category listing.
    cats = []

    # Do some pretty standard DOM-traversal to grab the ID and URL for each category.
    $('table#ctl00_ContentPlaceHolder1_grdCategories').find('tr').each (i, el) ->
      return if i == 0
      cats.push {
        label: $(@).find('td').eq(0).find('a').text(),
        url: "https://www.ips.state.nc.us/IPS/#{$(@).find('td').eq(0).find('a').attr('href')}"
      }

    # If the user has indicated they want to limit the number of results (via the --limit flag),
    # use Underscore's _.first to make it so.
    if opts.limit > 0
      cats = _.first(cats, opts.limit)

    # Using the async library, we'll make up to 5 concurrent requests to the procurement site.
    # We call the getRfpDetails() function for each one.
    # Once we're done, we call the done() function that was passed to us back in the `module.exports` definition.
    async.eachLimit cats, 5, scrapeCategory, (err) ->
      console.log(err.red) if err
      done rfps

 
  scrapeCategory = (cat, cb) ->
    rfps = []
    console.log "Examining #{cat.label}".yellow

    request.get cat.url, (err, response, body) ->
      $ = cheerio.load body
      $('table#ctl00_ContentPlaceHolder1_grdBidList').find('tr').each (i, el) ->
        # also removes whitespace
        number = $(@).find('td').eq(0).find('a').text().replace(/(^[\s]+|[\s]+$)/g, '')
        amendment = number.match(/-([0-9])$/)
        if amendment
          console.log(number.yellow)
          base = number.replace(amendment, '')
        else
          console.log(number.green)
        #amendment = number.match(/-\d/);
        #rfps.push {
        #id: $(@).find('td').eq(0).find('a').text(),
        #pdf_url: "https://www.ips.state.nc.us/IPS/#{$(@).find('td').eq(0).find('a').attr('href')}",
        #}

      cb()

  # A function for scraping the details from an department page. 
  getDeptDetails = (item, cb) ->

    request.get item.dept_url, (err, response, body) ->
      $ = cheerio.load body
      $table = $('table#ctl00_ContentPlaceHolder1_dvDept')

      for k, row of DEPT_ROWS
        item[k] = $table.find("tr").eq(row).find('td').eq(2).text()


      console.log "Department details loaded for #{item.section}".green

      cb()

