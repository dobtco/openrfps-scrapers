request = require 'request'
assert = require 'assert'
cheerio = require 'cheerio'
zombie = require 'zombie'
_ = require 'underscore'
require 'colors'

module.exports = (opts, done) ->

  itbs = []
  rfps = []
  page = 1
  pages = 1

  getItbs = (cb) ->
    request.get "http://www.purchasing.alabama.gov/txt/ITBs.aspx", (err, response, body) ->
      $ = cheerio.load body

      $('span[id=ctl00_ContentPlaceHolder2_Label1]').find('tr').each (i, el) ->
        if i != 0
          item = {}
          $(@).find('td').each (i, el) ->
            item.type = "ITB"
            switch i
              when 0
                item.id = $(@).text().trim()
                item.html_url = "http://www.purchasing.alabama.gov/txt/ITBs_details.aspx?type=at&snum=#{item.id}"
              when 1
                item.title = $(@).text().trim()
              when 2
                item.contact_name = $(@).text().trim()
                item.contact_email = $(@).find('a').attr('href').split(':').pop()
              when 3
                item.response_due_at = $(@).text().trim()
          itbs.push item
      cb()

      

  getRfps = (cb) ->
    browser = new zombie()
    browser.on("error", (error) -> console.error(error))
    browser
      .visit("http://rfp.alabama.gov/PublicView.aspx")
      .then( () ->
        browser.select("ctl00$MyContent$ddlStatus", "Open")
        )
      .then( () ->
        return browser.pressButton("Search")
        )
      .then( () ->
        assert.ok(browser.success)
        getRfpDetails(browser, browser.html())
        )
      .then( () ->
        cb()
        )  

  getRfpDetails = (browser, body) ->
    $ = cheerio.load body  
    # XXX: this is super janky and i'm embarrassed by it but it works
    rows = $('table[id=MyContent_GridViewRFP]').find('tr').length
    $('table[id=MyContent_GridViewRFP]').find('tr').each (i, el) ->   
      if i is (rows - 1)
        pages = $(@).find('td').length
      if i isnt 0 and i isnt (rows - 1) and i isnt (rows - 2)
        item = {}
        $(@).find('td').each (i, el) ->
          item.type = "RFP"
          switch i
            when 0
              item.id = $(@).text().trim()
            when 1
              description = $(@).text().split(':').pop().trim().split('.')
              item.title = description[0] + "."
              if description.length > 2 and description[1] isnt ''
                item.description = $(@).text().split(':').pop().trim()
            when 2
              item.department_name = $(@).text().trim()
        rfps.push item

    if page < pages
      page += 1
      browser
        .fill("input[name=__EVENTTARGET]", "ctl00$MyContent$GridViewRFP")
        .fill("input[name=__EVENTARGUMENT]", "Page$#{page}")
        .document.forms[0].submit()
      browser
        .wait()
        .then( () ->
          assert.ok(browser.success)
          getRfpDetails(browser, browser.html())
          )
    else
      rfps = _.uniq(rfps, (item) -> item.id)
      return rfps

  getRfps ->
    console.log "got #{rfps.length} rfps!".green
    getItbs ->
      console.log "got #{itbs.length} itbs!".green
      solicitations = _.union(rfps, itbs)
      done solicitations
