var cheerio = require("cheerio"),
    request = require("request"),
    _ = require("underscore"),
    async = require("async");

var START_URL = "http://www.purchase.state.il.us/ipb/IllinoisBID.nsf/viewsolicitationsopenbydate?openview&start=1&count=250?OpenView",
    BASE_URL = "http://www.purchase.state.il.us";

var FIELDS = {
    "Reference Number": "id",
    "Title": "title",
    "Agency": "department_name",
    "Published": "responses_open_at",
    "Due Date": "responses_due_at",
    "Name": "contact_name",
    "Phone": "contact_phone",
    "E-Mail Address": "contact_email",
    "description": "description",
    "Solicitation Type": "type"
}

// types of solicitations on Illinois Procurement Board and their associated
// types as defined on the repo master list
var RFP_TYPES = {
    "Request for Proposal": "RFP",
    "Invitation for Bid": "ITB",
    "Request for Information": "RFI",
    "Request for Quotes": "RFQ"
}

module.exports = function(opts, done) {
    getSolicitationUrls(START_URL, function(error, links) {
        links = opts.limit > 0 ? _.first(links, opts.limit) : links;
        async.mapLimit(links, 5, getSolicitationDetails, function(error, results) {
            if(error) { throw new Error(error); }
            console.log("Done scraping!")

            var validators = {
                "type": function(type) {
                    return _.indexOf(_.values(RFP_TYPES), type) > -1;
                }
            }
            done(_.filter(results, function(item) {
                return validateFields(item, validators);
            }));
        });
    });
}

// pull links for each solicitation
function getSolicitationUrls(startUrl, cb) {

    request.get(startUrl, function(error, response, body) {
        var $ = cheerio.load(body);
        cb(null, $("tr td table table tr[valign=top]").map(function(i, tr) {
            return BASE_URL + $("a", $(tr)).eq(0).attr("href");
            }).toArray());
    });
}

// pull the desired fields from each solicitation
function getSolicitationDetails(url, cb) {

    // for each solicitation there 6 <table> elements with information as follows
    // 0 identification
    // 1 overview
    // 2 key information
    // 3 solicitation contact
    // 4 class code
    // 5 attachments
    // for each table we define a function to pull the information from that table as a map
    // fields are then renamed according to the FIELDS constant defined above

    var rename = renamer(FIELDS);
    request.get(url, function(error, response, body) {
        var $ = cheerio.load(body),
            funcs = [getInformation, getOverview, getInformation, getInformation, null, null],
            loaders = {
                "type": function(solicitation) {
                    return RFP_TYPES[solicitation];
                }
            }

        var detailsByTable = $("br+table").map(function(i, table) {
            return _.isFunction(funcs[i]) ? rename(funcs[i](table)) : {};
        }).toArray().concat({"html_url": url});

        cb(null, loadFields(_.reduce(detailsByTable, function(memo, val, i) {
            return _.extend(memo, val);
        }, detailsByTable[0]), loaders));
    });
}

// table parsing functions //
function getInformation(table) {
    var $ = cheerio.load(table);
    return _.object($("tr", $(table)).map(function(i, tr) {
        return $("td font", $(tr)).map(function(i, td) {
            var html = $(td).html().trim();
            return !i ? html.replace(":", "") : html;
        });
    }).toArray());
}
function getOverview(table) {
    var $ = cheerio.load(table);
    return {"description": $("td", $(table)).last().text()};
}
// end table parsing functions //

// returns a function to rename a map based on given fields
// also acts as a filter, removing keys not in fields,
function renamer(fields) {
    return function(obj) {
        return _.reduce(fields, function(memo, val, key) {
            if(_.has(obj, key)) memo[fields[key]] = obj[key];
            return memo;
        }, {});
    }
}
// apply a function to item fields as defined in loaders
function loadFields(item, loaders) {
    return _.reduce(loaders, function(memo, func, key) {
        if(_.has(memo, key)) memo[key] = func(memo[key]);
        return memo;
    }, item)
}
// validate fields as defined in validators
function validateFields(item, validators) {
    return _.every(_.map(validators, function(func, key) {
        if(_.has(item, key)) return func(item[key]);
        return false;
    }))
}
