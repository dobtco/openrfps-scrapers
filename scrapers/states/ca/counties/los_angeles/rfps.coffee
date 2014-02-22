# Require the necessary modules.
Browser = require 'Zombie'
cheerio = require 'cheerio'
async = require 'async'
_ = require 'underscore'
require 'colors'

module.exports = (opts, done) ->

  rfps = []

  browser = new Browser()
  numPages = undefined
  currentPage = 0

  newPageLoaded = ->
    try
      cheerio.load(browser.html())
    catch
      return false

    true

  parsePage = (cb) ->
    currentPage += 1
    console.log "Parsing page #{currentPage}"
    $ = cheerio.load browser.html()

    $('table').eq(0).find('tr').each ->
      if $(@).find('td').length > 0
        rfps.push {
          id: $(@).find('td').eq(0).text()
          alt_id: $(@).find('td').eq(0).find('a').attr('href').match(/\d+/)[0]
        }

    if currentPage == numPages
      console.log "Done!"
      cb()
    else
      browser.fill('HiddenCurrPage', currentPage + 1)
      browser.evaluate "document.getElementById('BLU').submit()"
      browser.wait 500, ->
        browser.wait newPageLoaded, ->
          parsePage(cb)

  browser
    .visit('http://camisvr.co.la.ca.us/lacobids/BidLookUp/BLView.asp')
    .then ->
      numPages = parseInt(browser.text().match(/Page 1 of ([0-9]+)/)[1], 10)
      parsePage ->
        done(rfps)

    .fail (err) ->
      console.log err
