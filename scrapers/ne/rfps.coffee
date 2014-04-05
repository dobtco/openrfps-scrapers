request = require 'request'
requestsync = require 'request-sync'
cheerio = require 'cheerio'
jsdom = require 'jsdom'
jq = require 'jquery'
async = require 'async'
_ = require 'underscore'
YAML = require 'libyaml'
util = require __dirname + '/util'
require 'colors'

module.exports = (opts, done) ->
  # Read in config.yml to grab the URLs we need to parse
  CONFIG = YAML.readFileSync(__dirname + '/config.yml')[0]

  # Parses commodity-itb.html, returning an array of parsed RFPs
  parseCommodityRfpPage = (callback) ->
    results = []

    request.get CONFIG.commodity_url, (err, response, body) ->
      callback err, null if err

      jsdom.env
        html: body
        done: (errors, window) ->
          $ = jq(window)

          # Remove unnecessary bits
          $('s, br').remove() # remove the crossed out information
          $('p:empty, p:contains("&nbsp;")').remove() # remove unnecessary html
          $('tr.cell-purch:first').contents().unwrap('tr').wrap('th') # s/tr/th on the header rows

          $('.col4full750 tr.cell-purch').each (i, _) ->
            obj = {}
            obj.type = "ITB"
            obj.id = util.trim $(@).find('td:nth-child(3) a').text()
            obj.responses_open_at = util.trim $(@).find('td:nth-child(2)').text()
            obj.title = util.trim $(@).find('td:nth-child(1)').text()
            obj.commodity = obj.title
            obj.contact_name = util.trim $(@).find('td:nth-child(4)').text()
            obj.html_url = $(@).find('td:nth-child(3) a').attr('href')
            obj.html_url = "http://das.nebraska.gov/materiel/" + obj.html_url.substr(6)

            details = requestsync(
              method: 'GET'
              uri: obj.html_url
            )
            jsdom.env
              html: details.body
              done: (errors, window) ->
                $ = jq(window)

                obj.description = util.trim $('h6:contains("PROJECT DESCRIPTION")').next('p').text()
                obj.created_at = util.trim $('tr:contains("Invitation to Bid")').children('td:nth-child(2)').text()
                obj.responses_open_at = util.trim $('tr:contains("ITB Bid Opening Date")').children('td:nth-child(2)').text()

                $('tr:nth-child(3):contains("PDF")').each (i, _) ->
                  if not obj.downloads
                    obj.downloads = new Array()

                  obj.downloads.push CONFIG.bid_link_prefix + $(@).find('td:nth-child(3) a').attr('href')

                window.close

            # Done scraping; add this result and move on to the next
            console.log "Successfully downloaded #{obj.title}".green
            results.push obj

          window.close
          callback null, results

  # Parses services-rfp.html, returning an array of parsed RFPs
  parseServicesRfpPage = (callback) ->
    results = []

    request.post CONFIG.services_url, (err, response, body) ->
      callback err, null if err

      jsdom.env
        html: body
        done: (errors, window) ->
          jQuery = jq(window)

          # Remove unnecessary bits
          jQuery('s, br').remove() # remove the crossed out information
          jQuery('p:empty, p:contains("&nbsp;")').remove() # remove unnecessary html

          # "State Purchasing Processed Current Bid Opportunities"
          jQuery('.col4full750:first tr.cell-purch').each (i, _) ->
            obj = {}
            obj.type = "RFP"
            obj.id = util.trim jQuery(@).find('td:nth-child(4) a').text()
            obj.responses_open_at = util.trim jQuery(@).find('td:nth-child(2)').text()
            obj.updated_at= util.trim jQuery(@).find('td:nth-child(3)').text()
            obj.title = util.trim jQuery(@).find('td:nth-child(1)').text()
            obj.contact_name = util.trim jQuery(@).find('td:nth-child(5)').text()
            obj.html_url = CONFIG.bid_link_prefix + jQuery(@).find('td:nth-child(4) a').attr('href').substr(17)

            details = requestsync(
              method: 'GET'
              uri: obj.html_url
            )
            $ = cheerio.load(details.body)

            obj.description = util.trim $('b:contains("PROJECT DESCRIPTION")').next('span').text()
            obj.created_at = util.trim $('td:contains("Request for Proposal")').next('td').text()

            download_root = CONFIG.bid_link_prefix + obj.id.split(' ').join('') + '/'
            $('td a:contains("PDF")').each (i, _) ->
              if not obj.downloads
                obj.downloads = new Array()
              obj.downloads.push download_root + $(@).attr('href')
            $('td a:contains("Word")').each (i, _) ->
              if not obj.downloads
                obj.downloads = new Array()
              obj.downloads.push download_root + $(@).attr('href')

            # Done scraping; add this result and move on to the next
            results.push obj
            console.log "Successfully downloaded #{obj.title}".green

          # "State Purchasing Processed Proposals that have Opened"
          jQuery('.col4full750:eq(1) tr.cell-purch').each (i, _) ->
            obj = {}
            obj.type = "RFP"
            obj.awarded = true
            obj.id = util.trim jQuery(@).find('td:nth-child(5)').text()
            obj.updated_at= util.trim jQuery(@).find('td:nth-child(4)').text()
            obj.title = util.trim jQuery(@).find('td:nth-child(1)').text()
            obj.contact_name = util.trim jQuery(@).find('td:nth-child(6)').text()
            obj.html_url = CONFIG.bid_link_prefix + jQuery(@).find('a').attr('href').substr(17)

            details = requestsync(
              method: 'GET'
              uri: obj.html_url
            )
            $ = cheerio.load(details.body)

            obj.description = util.trim $('b:contains("PROJECT DESCRIPTION")').next('span').text()
            obj.created_at = util.trim $('td:contains("Request for Proposal")').next('td').text()

            download_root = CONFIG.bid_link_prefix + obj.id.split(' ').join('') + '/'
            $('td a:contains("PDF")').each (i, _) ->
              if not obj.downloads
                obj.downloads = new Array()
              obj.downloads.push download_root + $(@).attr('href')
            $('td a:contains("Word")').each (i, _) ->
              if not obj.downloads
                obj.downloads = new Array()
              obj.downloads.push download_root + $(@).attr('href')

            # Done scraping; add this result and move on to the next
            results.push obj
            console.log "Successfully downloaded #{obj.title}".green

          window.close
          callback null, results

  # Parses agency-rfp.html, returning an array of parsed RFPs
  parseAgencyRfpPage = (callback) ->
    results = []

    request.post CONFIG.agency_url, (err, response, body) ->
      callback err, null if err

      jsdom.env
        html: body
        done: (errors, window) ->
          jQuery = jq(window)

          # Remove unnecessary bits
          jQuery('br').remove() # remove the crossed out information
          jQuery('p:empty, p:contains("&nbsp;")').remove() # remove unnecessary html

          # "Agency Processed Current Bid Opportunities"
          jQuery('.col4full750:first tr.cell-purch').each (i, _) ->
            obj = {}
            obj.type = "RFP"
            obj.id = util.trim jQuery(@).find('td:nth-child(4) a').text()
            obj.responses_open_at = util.trim jQuery(@).find('td:nth-child(2)').text()
            obj.updated_at= util.trim jQuery(@).find('td:nth-child(3)').text()
            obj.title = util.trim jQuery(@).find('td:nth-child(1)').text()
            obj.department_name = util.trim jQuery(@).find('td:nth-child(5)').text()
            obj.html_url = CONFIG.bid_link_prefix + jQuery(@).find('td:nth-child(4) a').attr('href').substr(17)

            details = requestsync(
              method: 'GET'
              uri: obj.html_url
            )
            $ = cheerio.load(details.body)

            obj.description = util.trim $('h6:contains("PROJECT DESCRIPTION")').next('p').text()
            obj.contact_name = util.trim $('h6:contains("BUYER")').next('p').text()
            obj.created_at = util.trim $('tr:contains("Request for Proposal")').children('td:nth-child(2)').text()

            download_root = CONFIG.bid_link_prefix + obj.id.split(' ').join('') + '/'
            $('tr:nth-child(3) p a').each (i, _) ->
              if not obj.downloads
                obj.downloads = new Array()
              obj.downloads.push download_root + $(@).attr('href')

            # These dates aren't always filled in, so only add them if a real date is listed
            open_date = util.trim $('tr:contains("Evaluation Period")').children('td:nth-child(2)').text()
            if not 'XX/XX/XX' == open_date
              obj.responses_open_at = open_date

            due_date = util.trim $('tr:contains("Best and Final Offer")').children('td:nth-child(2)').text()
            if not 'XX/XX/XX' == due_date
              obj.responses_due_at = due_date

            duration = util.trim $('tr:contains("Effective"):contains("through") td:nth-child(1)').text()
            duration = duration.substr(duration.indexOf('Effective') + 10)
            if duration.indexOf('XXXX') < 0
              obj.duration = duration

            # Done scraping; add this result and move on to the next
            results.push obj
            console.log "Successfully downloaded #{obj.title}".green

          # "Agency Processed Proposals that have Opened"
          jQuery('.col4full750:eq(1) tr.cell-purch').each (i, _) ->
            obj = {}
            obj.type = "RFP"
            obj.awarded = true
            obj.id = util.trim jQuery(@).find('td:nth-child(5)').text()
            obj.updated_at= util.trim jQuery(@).find('td:nth-child(4)').text()
            obj.title = util.trim jQuery(@).find('td:nth-child(1)').text()
            obj.department_name = util.trim jQuery(@).find('td:nth-child(6)').text()

            # Done scraping; add this result and move on to the next
            results.push obj
            console.log "Successfully downloaded #{obj.title}".green

          # "Request for Information - Agency Processed"
          jQuery('.col4full750:eq(2) tr.cell-purch').each (i, _) ->
            obj = {}
            obj.type = "RFI"
            obj.id = util.trim jQuery(@).find('td:nth-child(4)').text()
            obj.updated_at= util.trim jQuery(@).find('td:nth-child(3)').text()
            obj.title = util.trim jQuery(@).find('td:nth-child(1)').text()
            obj.department_name = util.trim jQuery(@).find('td:nth-child(5)').text()

            obj.created_at = util.trim jQuery(@).find('td:nth-child(2)').text()
            if obj.created_at.indexOf('Withdrawn')
              obj.canceled = true
              obj.created_at = obj.created_at.substr(0, 8)

            # Done scraping; add this result and move on to the next
            results.push obj
            console.log "Successfully downloaded #{obj.title}".green

          window.close
          callback null, results



  # main() - parses all three pages at once, combines the results,
  # and sends the results back to OpenRFPs to generate the JSON
  # output file
  async.parallel
    commodity: (callback) ->
      parseCommodityRfpPage (err, data) ->
        callback err, data

    services: (callback) ->
      parseServicesRfpPage (err, data) ->
        callback err, data

    agency: (callback) ->
      parseAgencyRfpPage (err, data) ->
        callback err, data

  , (err, results) ->
    if err
      console.log err.read.red
    else
      data = []

      data = data.concat(results.commodity) if results.commodity
      data = data.concat(results.services) if results.services
      data = data.concat(results.agency) if results.agency

      done data
