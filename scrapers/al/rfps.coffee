request = require 'request'
cheerio = require 'cheerio'
_ = require 'underscore'
require 'colors'

module.exports = (opts, done) ->

  rfps = []

  getRfps = (cb) ->
    request.get 'http://localhost:8000/index.html', (err, response, body) ->
      $ = cheerio.load body

      $('span[id=ctl00_ContentPlaceHolder2_Label1]').find('tr').each (i, el) ->
        item = {}
        if i != 0
          $(@).find('td').each (i, el) ->   
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
              
          rfps.push item

      cb()


  getRfps ->
    console.log "done! scraped #{rfps.length} invitations to bid".green
    done rfps
