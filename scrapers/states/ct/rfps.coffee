# Require the necessary modules.
path = require 'path'
request = require 'request'
cheerio = require 'cheerio'
_ = require 'underscore'
Q = require 'q'
require 'colors'

DEBUG = true

# Set up some constants that we'll use later.
URLS =
  base:       "http://www.biznet.ct.gov/SCP_Search/"
  resultPage: "http://www.biznet.ct.gov/SCP_Search/Default.aspx"
  searchPage: "http://www.biznet.ct.gov/SCP_Search/BidResults.aspx"

FILTER_PARAMS =
  total: '#lbTotal'
  dataTable: '#GridView1'

BASIC_PARAMS =
  organization: 'Organization'
  salicitation_number: 'Solicitation Number'

logError = (reason) ->
  console.log "#{reason}".red
  if DEBUG and reason.stack?
    console.log "#{reason.stack}".replace(/^.*\n/, '').grey

# The use of cheerio's text() will concatinate text between tags with an empty
# string: 'foo<br>bar' will become 'foobar' not 'foo bar'. This is a problem
# for parsing text. Instead pull from html() and strip out the tags manually.
# For reference the text() is working as designed. It's the messed up HTML that
# uses markup to create whitespace.
stripTags = (html) ->
  html.replace(/(<[^>]+>|\s)+/g, ' ').trim()

totalResults = ($el, $) ->
  text = $el.text()
  total = parseInt(text, 10)
  throw new Error("#{text} is not a valid number") if _.isNaN(total)
  total

parseDate = ($el, $) ->
  # TODO: Cannot parse odd date format with native new Date()
  { responses_due_at: stripTags $el.html() }

parseContent = ($el, $) ->
  details = $el.find("td:contains(#{BASIC_PARAMS.salicitation_number})")
    .next('td').children('a').first()

  html_url = "#{URLS.base}#{details.attr('href')}"

  id = html_url.match(/CID=([^&]+)$/)?[1]

  title = stripTags details.html()

  department_name = stripTags(
    $el.find("td:contains(#{BASIC_PARAMS.organization})")
    .next('td').html()
  )

  # TODO: Add spaces between elements (text() concatinates with an empty
  # string).
  description = stripTags $el.html()

  canceled = (/cancel/i).test(description)

  if DEBUG
    console.log (if id? then "✔".green else "✘".red) + " #{id}: #{title.blue}"
    unless id?
      console.log "Problems processing '#{$el.html()}'".grey

  {
    id
    title
    html_url
    canceled
    description
    department_name
  }

parseConference = ($el) ->
  details = stripTags $el.html()
  matches = details.match(/(?:conference|webinar).+(?:on|at)\s+([\d\/]+)/i)
  return {} unless matches
  attendance_mandatory = /required|mandatory/i.test(details)
  datetime = matches[1]
  # TODO: I don't know how to parse this based on the sample data
  # address = ''
  # TODO: Currently only allows one conference
  prebid_conferences = [
    {
      attendance_mandatory
      datetime
      # address
    }
  ]
  {prebid_conferences}

processHTML = ($) ->
  try
    total = totalResults $(FILTER_PARAMS.total)
    console.log "Total number of RFPs: #{total}".green
  catch err
    console.log err.toString().red
    console.log "Unable to parse total number of RFPs; continuing blindly.".red

  # The page only spits out 20 at a time, But does offer a hint to the total.
  # (total / 20) = number of pages. `tbPageNumber` is used (zero based) for each page.
  theRows = $("#{FILTER_PARAMS.dataTable} tr")
    .first() # first tr is only headers
    .siblings() # grab all the tr's after this one
    .toArray()

  rfps = _(theRows).chain()
    .map (row) ->
      $(row).children('td').toArray()
    .map ([date, content]) ->
      date    = $(date)
      content = $(content)
      _.extend(
        parseContent(content, $),
        parseConference(content, $),
        parseDate(date, $)
      )
    .value()

  # If the user has indicated they want to limit the number of results (via the --limit flag),
  # use Underscore's _.first to make it so.
  if opts.limit > 0
    _(rfps).first(opts.limit)
  else
    rfps


# We'll export one function, that takes two parameters: an options hash,
# and a callback that must be executed once we're done scraping.
module.exports = (opts, done) ->

  # Site requires a session id saved as a cookie. Make our own (sandboxed)
  # cookie jar so subsequent requests use the same session id.
  cookieJar = request.jar()
  request = request.defaults jar: cookieJar

  # Node's callback patter is useful but looks ugly. Convert that pattern to
  # the promise pattern by wrapping the original function in a promise
  # returning function.
  requestPost = Q.denodeify request.post
  requestGet  = Q.denodeify request.get

  # Site requires POST data that is a 73K set of base64 encoded values.
  # Placed in a JSON file for easy use.
  formData = require './formdata.json'

  # Run out chain of events finishing with a call to the done() function.
  # Each link in the chain will return the value the next link needs to work
  # with. Eventually the last peice will be the array of RFPs.
  requestPage = (pageNumber) ->
    formData.tbPageNumber = pageNumber
    requestPost(URLS.resultPage, form: formData)

  requestPost(URLS.searchPage, form: formData)
    .then( -> requestGet(URLS.resultPage) )
    # Q will grab the arguments normally passed in to the node style callback
    # and instead return it as an array.
    .get(1) # snag the second argument (body)
    .then(cheerio.load) # Pass body into cheerio
    .then(processHTML)
    .then(done, logError)
    .done()

###
  # Send a POST request to the site's endpoint. Why we're POSTing to read data, you'll have to tell me...
  request.post 'http://ssl.doas.state.ga.us/PRSapp/PublicBidDisplay', form: FILTER_PARAMS, (err, response, body) ->
    # Load the resulting HTML into Cheerio, a jQuery-like DOM parser.

    $ = cheerio.load body

    # Do some pretty standard DOM-traversal to grab the ID and URL for each RFP.
    # We just need to get this preliminary information -- we'll scrape for the details later.
    $('table').eq(3).find('tr').each (i, el) ->
      return if i == 0

      rfps.push {
        id: $(@).find('td').eq(0).find('a').text(),
        html_url: "http://ssl.doas.state.ga.us/PRSapp/#{$(@).find('td').eq(0).find('a').attr('href')}"
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

###
