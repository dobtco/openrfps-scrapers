## Expected Scraper Output
Below, you'll find a JSON Schema that we'll expect your scrapers to output. Take note: this schema is designed to be as flexible as possible, for example, *both "2005-06-15T12:00:00Z" and "April 13th at 4pm" are valid entries in the `created_at` field*. Why is this? We want to make writing scrapers as easy and pain-free as possible. Scrapers should simply target HTML elements and extract their contents -- if those contents need to be transformed, we'll do that when we load the data into a database.

> This is a living document -- we expect it to become more complete as we write more scrapers. (Feel free to include a change to this document as you write scrapers.)

### RFP

| required? | key | description |
| --- | --- | --- |
| ✔ | `id` | A unique identifier string |
| ✔ | `type` | The type of posting, e.g. `RFP` or `RFI`. See the [master list](https://github.com/dobtco/openrfps-scrapers/blob/master/OUTPUT.md#rfp-types). If you need help choosing a type, feel free to open an issue. |
|   | `html_url` | A link to the RFP page |
| ✔ | `title` | Title |
|   | `department_name`| Department name |
|   | `address`| Full address related to this RFP (will be normalized later) |
|   | `awarded` | Boolean - has the RFP been awarded? (Leave blank for unknown) |
|   | `canceled` | Boolean - has the RFP been canceled? (Leave blank for unknown) |
|   | `contact_name` | Contact name |
|   | `contact_phone` | Contact phone |
|   | `contact_fax` | Contact fax |
|   | `contact_email` | Contact email |
|   | `created_at` | When was this RFP posted? |
|   | `updated_at` | When was this RFP revised? |
|   | `responses_open_at` | When do responses open? |
|   | `responses_due_at` | When are responses due? |
|   | `description` | Text/HTML description |
|   | `prebid_conferences` | Array of [Conference](https://github.com/dobtco/openrfps-scrapers/blob/master/OUTPUT.md#conference) objects |
|   | `downloads` | Array of file URLs |
|   | `nigp_codes` | Array of NIGP codes |
|   | `commodity` | String representing the commodity (we'll try to match it to a code) |
|   | `estimate` | Estimated cost of the contract |
|   | `duration` | Duration of contract |


#### Conference
| required? | key | description |
| --- | --- | --- |
| ✔ | `attendance_mandatory` | **Boolean** |
|   | `datetime` | When is the conference? |
|   | `address` | Full address for the conference (will be normalized later) |

#### RFP Types
| key | description |
| --- | --- |
| RFP | Request for proposal |
| RFI | Request for information |
| ITB | Invitation to bid |
| RFQ | Request for quotes |

> There's an endless number of these, so feel free to append to the list as necessary.

### Awards
@todo
