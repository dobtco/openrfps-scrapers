// modeled after the IL parser

var cheerio = require("cheerio"),
    request = require("request"),
    _ = require("underscore"),
    async = require("async"),
    url = require('url');

var START_URL = "http://www.in.gov/cgi-bin/idoa/cgi-bin/bidad.pl",
    BASE_URL = "http://www.in.gov";

module.exports = function(opts, done) {
    getSolicitationUrls(START_URL, function(error, links) {
        links = opts.limit > 0 ? _.first(links, opts.limit) : links;
        console.log(links)
        async.mapLimit(links, 5, getSolicitationDetails, function(error, results) {
            if(error) { throw new Error(error); }
            console.log("Done scraping!")
            done(results);
        });
    });
}

// pull links for each solicitation
function getSolicitationUrls(startUrl, cb) {
    request.get(startUrl, function(error, response, body) {
        var $ = cheerio.load(body);
        cb(null, $("center table tr").map(function(i, tr) {
            if(i > 0){ // because :gt(0) isn't supported
                return BASE_URL + $("td:nth-child(2) a", $(tr)).eq(0).attr("href");    
            }
            }).toArray());
    });
}

// pull the desired fields from each solicitation
function getSolicitationDetails(link, cb) {

    request.get(link, function(error, response, body) {
        var $ = cheerio.load(body);
        var details = {}
        var link_parsed = url.parse(link,true)

        details["html_url"] = link
        details["id"] = link_parsed.query.spec
        details["type"] = link_parsed.query.method
        details["title"] = link_parsed.query.desc

        pre_text = $("body pre").text()
        details["responses_open_at"] = pre_text.match(/OPENING.+(\d{1,2}\/\d{1,2}\/\d{4})/)[1]
        details["contact_name"] = (pre_text.match(/BUYER:\s(.+,.+)/)[1]).trim()

        // TODO: follow links to actual solicitation content and downloable asset links 

        cb(null, details);
    });
}
