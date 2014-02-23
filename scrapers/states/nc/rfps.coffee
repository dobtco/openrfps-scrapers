# Require the necessary modules.
request = require 'request'
cheerio = require 'cheerio'
async = require 'async'
_ = require 'underscore'
require 'colors'

# Set up some constants that we'll use later.
BASIC_PARAMS =
  number: 'Bid Number'
  description: 'Description'
  created_at: 'Date Issued'
  opening_date: 'Bid Opening Date'
  opening_time: 'Bid Opening Time'
  department: 'Help'



# We'll export one function, that takes two parameters: an options hash,
# and a callback that must be executed once we're done scraping.
module.exports = (opts, done) ->

  # Set up an empty array for our RFPs.
  rfps = []

  # Send a POST request to the site's endpoint. Why we're POSTing to read data, you'll have to tell me...
  request.get 'https://www.ips.state.nc.us/IPS/catbids.aspx', (err, response, body) ->

    # Load the resulting HTML into Cheerio, a jQuery-like DOM parser.
    $ = cheerio.load body

    # State of NC begins with a category listing.  I'm not strong enough with
    # CoffeeScript right now to make this an optional thing, let's crawl everywhere.

    # Do some pretty standard DOM-traversal to grab the ID and URL for each category.
    $('table#ctl00_ContentPlaceHolder1_grdCategories').find('tr').each (i, el) ->
      return if i == 0
      category_label = $(@).find('td').eq(0).find('a').text()
      category_url = "https://www.ips.state.nc.us/IPS/#{$(@).find('td').eq(0).find('a').attr('href')}"

      # More DOM traversal for the actual RFP
      request.get category_url, (err, response, body) ->
        $category = cheerio.load body
        $category('table#ctl00_ContentPlaceHolder1_grdBidList').find('tr').each (i, el) ->
          #dept_text = $category(@).find('td').eq(5).find('a').text()
          #dept_url = "https://www.ips.state.nc.us/IPS/#{$category(@).find('td').eq(5).find('a').attr('href')}"
          console.log(dept_url)
          rfps.push {
            id: $category(@).find('td').eq(0).find('a').text(),
            pdf_url: $category(@).find('td').eq(0).find('a').attr('href')}
            #dept_url: "https://www.ips.state.nc.us/IPS/#{$category(@).find('td').eq(5).find('a')}"
          }
       

    # If the user has indicated they want to limit the number of results (via the --limit flag),
    # use Underscore's _.first to make it so.
    if opts.limit > 0
      rfps = _.first(rfps, opts.limit)

    # Using the async library, we'll make up to 5 concurrent requests to the procurement site.
    # We call the getRfpDetails() function for each one.
    # Once we're done, we call the done() function that was passed to us back in the `module.exports` definition.
    async.eachLimit rfps, 5, getRfpDetails, (err) ->
      console.log(err.red) if err
      done rfps

  # A function for scraping the details from an RFP page. It's just more DOM-traversal,
  # so it should look familiar by now.
  getRfpDetails = (item, cb) ->
    return getMaintenanceRfpDetails(item, cb) if item.html_url.match 'maintanence'

    request.get item.html_url, (err, response, body) ->
      $ = cheerio.load body
      $table = $('table').eq(1)

      for k, v of BASIC_PARAMS
        item[k] = $table.find("tr:contains(#{v})").find('td').eq(3).text()

      item.external_url = $table.find('a:contains(Link to Agency Site)').attr('href')
      item.description = $('[name=bidD]').val()
      item.prebid_conferences = []

      if $('body').text().match /prebid/i
        $table2 = $('table').eq(2)

        item.prebid_conferences.push {
          attendance_mandatory: if $table2.find('tr:contains(Prebid Conference Attendance)').find('td').eq(1).text().match('Mandatory') then true else false
          datetime: $table2.find('tr:contains(Prebid Conference Date/Time)').find('td').eq(1).text()
          address: $table2.find('tr:contains(Prebid Location)').find('td').eq(1).text() + "\n" +
                   $table2.find('tr:contains(Prebid Street)').find('td').eq(1).text() + "\n" +
                   $table2.find('tr:contains(Prebid City)').find('td').eq(1).text() + ", " +
                   $table2.find('tr:contains(Prebid State)').find('td').eq(1).text() + " " +
                   $table2.find('tr:contains(Prebid Zip Code)').find('td').eq(1).text()
        }

      item.nigp_codes = []
      $('h2:contains(NIGP codes assigned to bid)').next('table').find('a').each ->
        item.nigp_codes.push $(@).text()

      item.downloads = []
      $('h2:contains(Documents)').nextAll().filter( (-> $(@).is('table')) ).eq(0).find('a').each ->
        item.downloads.push $(@).attr('href')

      console.log "Successfully downloaded #{item.title}".green

      cb()

  # Maintenance RFPs have a different layout than the other RFPs.
  # See http://ssl.doas.state.ga.us/PRSapp/maintanence?eQHeaderPK=125334&source=publicViewQuote for an example.
  getMaintenanceRfpDetails = (item, cb) ->
    request.get item.html_url, (err, response, body) ->
      $ = cheerio.load body
      $table = $('table').eq(3)

      for k, v of MAINTENANCE_BASIC_PARAMS
        item[k] = $table.find("tr:contains(#{v})").find('td').eq(1).text()

      item.industry_codes =
        nigp: $table.find("tr:contains(NIGP Code Selection)").find('td').eq(1).text().match(/(\d+)/ig)

      cb()


