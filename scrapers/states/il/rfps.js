
var cheerio = require("cheerio"),
    request = require("request"),
    _ = require("underscore"),
    async = require("async");

var START_URL = "http://www.purchase.state.il.us/ipb/IllinoisBID.nsf/viewsolicitationsopenbydate?openview&start=1&count=250?OpenView",
    BASE_URL = "http://www.purchase.state.il.us";

var fields = {};


// pull links for each solicitation
function getSolicitationLinks(startHtml) {

    var $ = cheerio.load(startHtml);
    return $("tr td table table tr[valign=top]")
        .map(function(i, tr) {
            return BASE_URL + $("a", tr).eq(0).attr("href");
        });
}

// pull the desired fields from each solicitation
function getSolicitationDetails(html) {



}

