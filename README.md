## The Open RFP Project

The OpenRFP Project is modeled after Sunlight Labs' [OpenStates](https://github.com/sunlightlabs/openstates/tree/master/openstates) project. It collects and makes available data about contracting activities, including RFP listings as well as awards, and makes that information available in a standard format.

## Contribution Guidelines
At present, the project is just focused on building scrapers, and getting that data into JSON format. 

TODO: Talk about how scrapers should be written. Adam, see [here](http://openstates.org/contributing/)

Scrapers can be found in the scrapers/ directory, with a separate directory for each state using that state's two letter abbreviation. Each state should have at least three files:

### config.yml
Basic configuration and metadata for the parsers. See samplestate.yml in the scrapers directory. 

### rfps.rb

This handles the scraping of RFPs since the last timestamp from the specified government's website. This should output into a specified rfps.json file in a data directory relative to where the scraper was called.

### awards.rb
Some states make their awarded contracts available separately from their rfp listing websites. Awards.rb should crawl for contracts that have been awarded, and gather that metadata, and output it into a specified awards.json file in a data directory relative to where the scraper was called. 

## Counties, Cities, and other governmental procurement websites
Other governmental bodies are also welcome. Should you write a scraper for them, please place them in a cities/[CITYNAME] or counties/[COUNTYNAME] directory using the same file handling.

## Why this is important
We're doing this for two reasons: 

1. Because citizens have a right to know what kinds of RFPs their governments are releasing to the public, who is being awarded these contracts, and for how much.

2. Because we want to open up the marketplace -- and state procurement websites are so abyssmal that they are nearly impossible to use in any regular kind of way. 

By enabling more companies to compete for these contracts, we think that this can unlock a lot of potential for civic innovation, increase competition,  decrease the cost of government, and increase the level of service delivery. We hope you'll join us for the long haul.

## If You Run One Of These Sites
Please contact us at openrfps@dobt.co if you'd like to contribute a direct source to your state's procurement website.
