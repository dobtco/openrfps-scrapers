var cheerio = require("cheerio"),
    request = require("request"),
    _ = require("underscore");

var START_URL = "http://www.arkansas.gov/dfa/procurement/bids/index.php",
    BASE_URL = "http://www.arkansas.gov/dfa/procurement/bids/";


module.exports = function(opts, done) {
    getSolicitationUrls(START_URL, function(links) {
        console.log(links);
    });
}

// pull links for each solicitation (needed for attachments)
function getSolicitationUrls(startUrl, cb) {

    request.get(startUrl, function(error, response, html) {
        if(!error) {
            var urls = [];
            var $ = cheerio.load(html);
            $('table tr td font.rowitem1 a').each(function(){
                var url = BASE_URL + $(this).attr('href');
                urls.push(url);
            });
            cb(urls);
            
        }
    });
}
