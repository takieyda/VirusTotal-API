# Virus Total URL Query

Just a simple PowerShell script to automate the retrieval or scanning of URLs. 

## Features

- Queries Virus Total and retrieves scan data
  - Maliicous positives
  - Scan date
  - Permalink to scan report
- Submits a URL to be scanned if it's not in the dataset
- Resubmits a URL to be scanned if most recent scan date is older than 6 months
- Displays script progress and results per URL
- Displays tables of malicious URLs and URLs where no scan report was found
- Exports scan data to CSV
  - Malicious positives
  - URL
  - Scan date
  - Permalink to scan report
- Estimates time to completion, and calculates time taken when complete

## Usage

1. Enter or paste list of URLs to query in domains.txt, each on a separate line.
2. Run vt_url_query.ps1 in PowerShell.
3. Malicious results and URLs with no scan reports exported to CSV in working directory.

## Known issues

- ~~Script will produce errors if submitting a URL for scanning and it is queued~~
  - Results in URL being placed in the list of URLs without scan reports
  - **Hopefully fixed in v1.05**

## To do

- [x] Fix variable scope issues
- [x] Submit URL for re-scanning if most recent scan is older than 6 months
- [x] Handle scan queues which produce errors during script
  - Check HTTP status codes on responses
  - Check VT verbose_msg value
  - If queued, add to new hash table to be rescanned
    - Remove URL, check status, process if not queued, add back to hash table if still queued
