request = require 'request'
cheerio = require 'cheerio'
async = require 'async'
_ = require 'underscore'

require 'colors'

FILTER_PARAMS =
  track: ''
  bidResponse: 'all'
  theType: 'OPEN'
  govType: 'state'
  theAgency: 'all'
  theWord: ''
  theSort: 'BID NUMBER'

BASIC_PARAMS =
  title: 'Bid Title'
  contact_name: 'Contact Person'
  contact_phone: 'Contact Phone Number'
  contact_email: 'Contact E-mail Address'
  created_at: 'Date Posted'
  updated_at: 'Last Revision Date'

module.exports = (opts, done) ->
  getRfpDetails = (item, cb) ->
    # Don't process maintenance yet
    # looks like: http://ssl.doas.state.ga.us/PRSapp/maintanence?eQHeaderPK=125334&source=publicViewQuote
    return cb() if item.html_url.match 'maintanence'

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

      item.industry_codes = { nigp: [] }
      $('h2:contains(NIGP codes assigned to bid)').next('table').find('a').each ->
        item.industry_codes.nigp.push $(@).text()

      item.downloads = []
      $('h2:contains(Documents)').nextAll().filter( (-> $(@).is('table')) ).eq(0).find('a').each ->
        item.downloads.push $(@).attr('href')

      console.log "Successfully downloaded #{item.title}".green

      cb()

  rfps = []

  request.post 'http://ssl.doas.state.ga.us/PRSapp/PublicBidDisplay', form: FILTER_PARAMS, (err, response, body) ->
    $ = cheerio.load body

    $('table').eq(3).find('tr').each (i, el) ->
      return if i == 0

      rfps.push {
        id: $(@).find('td').eq(0).find('a').text(),
        html_url: "http://ssl.doas.state.ga.us/PRSapp/#{$(@).find('td').eq(0).find('a').attr('href')}"
      }

    if opts.limit > 0
      rfps = _.first(rfps, opts.limit)

    async.eachLimit rfps, 5, getRfpDetails, (err) ->
      console.log(err.red) if err
      done rfps
