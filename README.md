## The Open RFPs Project

The Open RFPs Project is modeled after Sunlight Labs' [OpenStates](https://github.com/sunlightlabs/openstates/tree/master/openstates). Open RFPs collects and makes available data about contracting activities, including RFP listings as well as awards, and makes that information available in a standardized format.

## Contribution guidelines
It's early days, and we're still figuring out the best development toolchain and methods for structuring these scrapers. We've chosen node.js because of its module-loading implementation, its accessibility to the programming community ("Everyone knows Javascript!"), and capacity for asynchronicity. Expect this section of the README to morph into its own separate guide in the near-future.

At present, the project is just focused on building scrapers, and getting that data into JSON format. The scrapers can be found in the scrapers/ directory, with a separate directory for each state using that state's two letter abbreviation. Each state should have at least three files:

### config.yml
Basic configuration and metadata for the parsers. [See an example](https://github.com/dobtco/openrfps/blob/master/scrapers/states/ga/config.yml).

### rfps.coffee (or rfps.js)
This is the important one: it handles the scraping of RFPs the specified government's website. [See an example](https://github.com/dobtco/openrfps/blob/master/scrapers/states/ga/rfps.coffee), or [read the annotated source](http://dobtco.github.io/openrfps/docs/rfps.html).

### Counties, cities, and other governmental procurement websites
Other governmental bodies are also welcome. Should you write a scraper for them, please place them in a `cities/[CITYNAME]` or `counties/[COUNTYNAME]`directory using the same file structure otherwise.

### Development tools
We've built a lightweight command-line interface to help you write scrapers. If you run `bin/openrfps --help` from the project root, you'll see some info:

```
  Usage: openrfps [options] [command]

  Commands:

    run <file>             run a scraper and output the results
    test <file>            test a scraper
    help [cmd]             display help for [cmd]

  Options:

    -h, --help     output usage information
    -V, --version  output the version number
```

While starting to develop a scraper, you'll probably want to use a command like:

```
bin/openrfps run scrapers/states/ga/rfps.coffee
```

This command will:

1. Run the Georgia RFP scraper
2. Cache its results to `scrapers/states/ga/rfps.json`
3. Pretty-print the returned JSON

Once you're confident that your results are shaping up, try running them against our [small suite of tests](https://github.com/dobtco/openrfps/blob/master/bin/openrfps-test):

```
bin/openrfps test scrapers/states/ga/rfps.coffee
```

By default, the `test` command will use the cached `.json` file that we downloaded earlier. To merge the two commands -- both running and testing in one command, you can use:

```
bin/openrfps test scrapers/states/ga/rfps.coffee --force
```

### What about the schema?
See [EXPECTED_SCRAPER_OUTPUT.md](https://github.com/dobtco/openrfps/blob/master/EXPECTED_SCRAPER_OUTPUT.md) for the current schema.

## Why this is important
We're doing this for two reasons:

1. Because citizens have a right to know what kinds of RFPs their governments are releasing to the public, who is being awarded these contracts, and for how much.

2. Because we want to open up the marketplace -- and state procurement websites are so abyssmal that they are nearly impossible to use in any regular kind of way.

By enabling more companies to compete for these contracts, we think that this can unlock a lot of potential for civic innovation, increase competition,  decrease the cost of government, and increase the level of service delivery. We hope you'll join us for the long haul.

## If you run an RFP listing site
Please contact us at openrfps@dobt.co if you'd like to contribute a direct source to your state's procurement website.
