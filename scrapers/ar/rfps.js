var cheerio = require("cheerio"),
    request = require("request"),
    _ = require("underscore");

var START_URL = "http://www.arkansas.gov/dfa/procurement/bids/index.php",
    BASE_URL = "http://www.arkansas.gov/dfa/procurement/bids/";

var FIELDS = {
    "Bid Number:": "id",
    "Agency:": "department_name",
    "Description:": "title"
}

module.exports = function(opts, done) {
    getSolicitationUrls(START_URL, function(links) {
        //console.log(links);
        links.forEach(function(link){
            getSolicitationDetails(link, function(table) {
                //console.log(table);
            });
        });
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

function getSolicitationDetails(url, cb){
    request.get(url, function(error, response, html) {
        var $ = cheerio.load(html);
        $('#mainContent table tr td[align="center"] div[align="center"] table td').each(function() {
                event = $(this).text().trim();
                    if (event in FIELDS) {
                        console.log(event);
                        console.log($(this).next().text().trim());
                    }
            });
    });
}


