# Require the necessary modules.
request = require 'request'
jsdom = require 'jsdom'
async = require 'async'
_ = require 'underscore'
fs = require 'fs'
require 'colors'

EMAIL_REGEX = /(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))/
PHONE_REGEX = /Phone\: (\([0-9]{3}\) [0-9]{3}-[0-9]{4})/

NUM_RESULTS_PER_PAGE = 25

FORM_DATA =
  TON:1
  Alpha:true
  ProcurCat:0
  Type:'A'
  searchDescriptions:'yes'
  qryType:'all'

module.exports = (opts, done) ->

  rfps = []
  currentPage = 0

  getPage = (cb) ->
    currentPage += 1
    console.log "Getting page #{currentPage}"

    moreParams = if currentPage == 1
      { }
    else if currentPage == 2
      { startPoint: 0, hdnNextAD: 'next' }
    else
      { startPoint: (currentPage - 2) * 25, hdnNextAD: 'next' }

    request.post 'http://a856-internet.nyc.gov/nycvendoronline/vendorsearch/asp/Postings.asp',
      form: _.extend(moreParams, FORM_DATA),
    , (err, response, body) ->
      console.log "Received page #{currentPage}".yellow

      jsdom.env
        html: body
        done: (errors, window) ->
          $ = require('jquery')(window)

          $('#bodywrapper').contents().filter ->
            @nodeType == 3 && $.trim(@nodeValue) != ''
          .wrap('<span/>')

          $('.Hbox-blue').each (i, _) ->
            unless $(@).text().match /Records \d+ to/
              $(@).nextUntil('.Hbox-blue').wrapAll("<div class='rfp-wrap' />")

          $('.rfp-wrap').each (i, _) ->
            item = {}

            item.title = $(@).find('h4').text()

            $(@).find('h4').nextUntil('.Hbox-grey').filter('br').replaceWith("<div>\n</div>")
            item.description = $(@).find('h4').nextUntil('.Hbox-grey').text()

            item.id = item.description.match(/PIN\# (\S+)/)?[1] ||
                      item.description.match(/RFQ\s+\#\s+((\S+)(\s+)?A?R?S?)/)?[1]

            unless item.id
              console.log item.description
              console.log "Couldn't load #{item.title} -- no ID found".red
              return

            item.responses_due_at = $(@).find('h5:contains("Due Date")')[0]?.nextSibling.data
            item.created_at = $(@).find('h5:contains("Published")')[0]?.nextSibling.data
            item.department_name = $(@).find('h5:contains("Agency")')[0]?.nextSibling.data
            item.address = $(@).find('h5:contains("Address")')[0]?.nextSibling.data

            contactText = $(@).find('h5:contains(Contact)').parent().html()?.replace(/<br>/ig, ' ')

            if contactText
              item.contact_name = $(@).find('h5:contains(Contact)')[0]?.nextSibling.data
              item.contact_email = contactText.match(EMAIL_REGEX)?[0]
              item.contact_phone = contactText.match(PHONE_REGEX)?[1]

            item.type = if item.id.match 'RFQ'
              'RFQ'
            else if $(@).find('h5:contains("Solicitation")')[0]?.nextSibling.data.match 'Request for Information'
              'RFI'
            else
              'RFP'

            console.log "Added item #{item.id}".green
            rfps.push item

          if opts.limit > 0 && (currentPage * NUM_RESULTS_PER_PAGE >= opts.limit)
            return cb()

          if $('#A1').length > 0
            getPage(cb)
          else
            cb()

  getPage ->
    console.log "All done! Found #{rfps.length} RFPs.".green
    done rfps
