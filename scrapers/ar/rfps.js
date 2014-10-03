var cheerio = require("cheerio"),
    request = require("request"),
    _ = require("underscore"),
    async = require("async");

var START_URL = "http://www.arkansas.gov/dfa/procurement/bids/index.php",
    BASE_URL = "http://www.arkansas.gov/dfa/procurement/bids/";

var FIELDS = {
    "Bid Number:": "id",
    "Agency:": "department_name",
    "Description:": "title",
    "Buyer's Email:": "contact_email"
}

module.exports = function(opts, done) {
    getSolicitationUrls(START_URL, function(links) {
        //copied from illinois scraper example
        links = opts.limit > 0 ? _.first(links, opts.limit): links;
        async.mapLimit(links, 5, getSolicitationDetails, function(error, results) {
        if(error) {throw new Error(error); }
        console.log("Done scraping!");
        done(results);
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
    var json = {"id": "","html_url": url, "type": "RFP"};
    request.get(url, function(error, response, html) {
        var $ = cheerio.load(html);
        $('#mainContent table tr td[align="center"] div[align="center"] table td').each(function() {
                event = $(this).text().trim();
                if (event in FIELDS) {
                    json[FIELDS[event]] = $(this).next().text().trim();
                }
        });
    cb(null, json);
    });
}


