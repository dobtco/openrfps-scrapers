Browser = require 'zombie'

module.exports = (done) ->

  browser = new Browser()

  browser
    .visit('http://ssl.doas.state.ga.us/PRSapp/PR_index.jsp')
    .then ->
      console.log browser.text()
      done []
