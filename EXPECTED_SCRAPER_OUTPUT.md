## Expected Scraper Output
Below, you'll find a JSON Schema that we'll expect your scrapers to output. Take note: this schema is designed to be as flexible as possible, for example, *both "2005-06-15T12:00:00Z" and "April 13th at 4pm" are valid entries in the `created_at` field*. Why is this? We want to make writing scrapers as easy and pain-free as possible. Scrapers should simply target HTML elements and extract their contents -- if those contents need to be transformed, we'll do that when we load the data into a database.

> This is a living document -- we expect it to become more complete as we write more scrapers. (Feel free to include a change to this document as you write scrapers.)

### RFP

| required? | key | description |
| --- | --- | --- |
| ✔ | `id` | A unique identifier string |
|   | `status` | [Status](https://github.com/dobtco/openrfps/blob/master/EXPECTED_SCRAPER_OUTPUT.md#valid-statuses) of the RFP |
|   | `html_url` | A link to the RFP page |
| ✔ | `title` | Title |
|   | `department_name`| Department name |
|   | `contact_name` | Contact name |
|   | `contact_phone` | Contact phone |
|   | `contact_email` | Contact email |
|   | `created_at` | When was this RFP posted? |
|   | `updated_at` | When was this RFP revised? |
|   | `responses_due_at` | When are responses due? |
|   | `description` | Text/HTML description |
|   | `prebid_conferences` | Array of [Conference](https://github.com/dobtco/openrfps/blob/master/EXPECTED_SCRAPER_OUTPUT.md#conference) objects |
|   | `downloads` | Array of file URLs |
|   | `nigp_codes` | Array of NIGP codes |


#### Conference
| required? | key | description |
| --- | --- | --- |
| ✔ | `attendance_mandatory` | **Boolean** |
|   | `datetime` | When is the conference? |
|   | `address` | Full address for the conference (will be normalized later) |

#### Valid statuses
- **Posted:** posted but not yet accepting responses
- **Open:** currently accepting responses
- **Closed:** no longer accepting responses
- **Awarded:** no longer accepting responses, and a winning bid has been announced
- **Cancelled:** self-explanatory


### Awards
@todo
