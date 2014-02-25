request = require 'request'
cheerio = require 'cheerio'
require 'colors'

module.exports = (opts, done) ->

  itbs = []

  getItbs = (cb) ->
    request.get 'http://www.purchasing.alabama.gov/txt/ITBs.aspx', (err, response, body) ->
      $ = cheerio.load body

      $('span[id=ctl00_ContentPlaceHolder2_Label1]').find('tr').each (i, el) ->
        item = {}
        if i != 0
          $(@).find('td').each (i, el) ->   
            item.is_itb = true
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


  getItbs ->
    console.log "done! scraped #{itbs.length} ITBs".green
    done itbs
