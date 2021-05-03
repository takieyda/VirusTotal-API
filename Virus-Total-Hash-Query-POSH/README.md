# Virus-Total-Hash-Query-POSH
Powershell implementation of the VirusTotal API to query for file hashes (SHA1).

## generate_hashes_from_dir.ps1
Recursively generates hashes (SHA1) for files starting from execution directory and exports to a CSV with filename, hash, algorithm, and relative path.
1. Copy to directory with files to hash
2. Execute PS1 file
3. Hashes will be exported to CSV file

## vt_hash_query.ps1
Takes input from generate_hashes_from_dir.ps1 CSV and queries each hash against the VirusTotal API. Results are output to CSV.

> NOTE: This script does not upload any files to VirusToal.
