## The Open RFPs Project

The Open RFPs Project is modeled after Sunlight Labs' [OpenStates](https://github.com/sunlightlabs/openstates/tree/master/openstates). Open RFPs collects and makes available data about contracting activities, including RFP listings as well as awards, and makes that information available in a standardized format.

### Community

**IRC:** Find us on #openrfps on [Freenode](http://freenode.net/).

## Contribution guidelines
The first thing to contribute is the location of the best starting page in your state for someone to create a scraper. You can add that to [the wiki page](https://github.com/dobtco/openrfps-scrapers/wiki/List-of-Procurement-Websites).

It's early days, and we're still figuring out the best development toolchain and methods for structuring these scrapers. Expect this section of the README to morph into its own separate guide in the near-future.

At present, this project is focused on building scrapers that collect RFP data into JSON documents. The scrapers can be found in the [scrapers/](https://github.com/dobtco/openrfps-scrapers/tree/master/scrapers) directory, with a separate directory for each state using that state's two letter abbreviation (for example: CA, OR, etc.).

An RFP scraper for a given state should have at least three files in its directory:

### config.yml
Basic configuration and metadata for the parsers. [See our example config.yml](https://github.com/dobtco/openrfps-scrapers/blob/master/scrapers/ga/config.yml).

### rfps.coffee (or rfps.js)
This is the important one, as it handles the scraping of RFPs from the specified government's website. [See an example](https://github.com/dobtco/openrfps-scrapers/blob/master/scrapers/ga/rfps.coffee), or [read the annotated source](http://dobtco.github.io/openrfps/docs/rfps.html).

### Counties, cities, and other governmental procurement websites
Other governmental bodies are also welcome. Should you write a scraper for them, you can add them in a `cities/[CITYNAME]` directory inside the appropriate state's directory.

So far, we have:

- Cities: `ca/cities/san-francisco`
- Counties: `ca/counties/alameda`
- School districts: `ca/schools/busd`

Make sure your scraper provides the same three files described above in its directory. We're happy to accept contributions of any kind, but remember that our primary goal is all 50 states.

## Development tools
We've chosen [Node.js](http://nodejs.org/) because of its module-loading implementation, its accessibility to the programming community ("Everyone knows Javascript!"), and its asynchronous-by-default approach. As with most Node.js projects, we use [npm](https://www.npmjs.org/) to [package](https://github.com/dobtco/openrfps-scrapers/blob/master/package.json) this project and specify its dependencies. We like [CoffeeScript](http://coffeescript.org/) for its expressiveness and improvements over JavaScript, but you can write your scraper in any language that compiles to JavaScript.

### Install dependencies
1. [node.js + npm](http://nodejs.org)
2. install the `coffee-script` package globally: `npm install -g coffee-script`.
3. install the rest of the dependencies: `npm install`

### `openrfps` on the command line
We've built a lightweight command-line interface to help you run and test scrapers. If you run `bin/openrfps --help` from the project root, you'll see some info:

    Usage: openrfps [options] [command]

    Commands:

      run <file>             run a scraper and output the results
      test <file>            test a scraper
      help [cmd]             display help for [cmd]

    Options:

      -h, --help     output usage information
      -V, --version  output the version number

While starting to develop a scraper, you'll probably want to use a command like:

    bin/run-scraper scrapers/ga/rfps.coffee

This command will:

1. Run the Georgia RFP scraper.
2. Cache its results to `scrapers/ga/rfps.json`.
3. Pretty-print the returned JSON.

Once you're confident that your results are shaping up, try running them against our [test suite](https://github.com/dobtco/openrfps-scrapers/blob/master/bin/openrfps-test):

    bin/test-scraper scrapers/ga/rfps.coffee

By default, the `test` command will use the cached `.json` file that we downloaded earlier.

To run both the scraper and the tests all with one command:

    bin/test-scraper scrapers/ga/rfps.coffee --force

### What about the schema?
See [OUTPUT.md](https://github.com/dobtco/openrfps-scrapers/blob/master/OUTPUT.md) for the current schema.

## Why this is important
We're doing this for two reasons:

1. Because citizens have a right to know what kinds of RFPs their governments are releasing to the public, who is being awarded these contracts, and how much those projects cost.

2. Because we want to open up the marketplace, and we believe that process starts with usability and accessibility. State procurement websites are very challenging to use by even highly computer-literate individuals, to say nothing of automating the bidding process.

By enabling more companies to compete for these contracts, we think that this can unlock a lot of potential for civic innovation, increase competition,  decrease the cost of government, and increase the level of service delivery. We hope you'll join us for the long haul.

## For government
We're excited to partner with government agencies who are willing to publish their data in an open, standard format from the start. You can contact us using [this form](https://screendoor.dobt.co/dobt/openrfps-government-interest-form).
