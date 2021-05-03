# Virus Total URL Query script
# Version 1.12
 
# $api_key_file = Get-Content $script_path\api_key.txt | Out-String | ConvertFrom-StringData
$api_key = "" # $api_key_file.api_key
$start = Get-Date
$stop = Get-Date

function get_dir {
    $invoke = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $invoke.MyCommand.Path
}

$script_path = get_dir

$input_file = $script_path + "\domains.txt"
$cnt = 0

$mal_hits = 0
$mal_urls = [ordered]@{}

$queued_urls = New-Object System.Collections.Generic.List[System.Object]

 
function pause {
    Read-Host "`n`nPress Enter to continue." | Out-Null
}
 
function check_api_key {
    # $api_check = Get-Content $script_path\api_key.txt | Out-String | ConvertFrom-StringData
    If (-not $Script:api_key) {
        Write-Host "`n`n*** Virus Total API key not present in the api_key variable. ***`n" -ForegroundColor Yellow
        pause
        Break
    }
}
 
function welcome {
    Write-Host "`n`n================================`n|    Virus Total URL Query     |`n================================"
    Write-Host "`nInfo: Due to restrictions for public API use, `nInfo: there is a 26 second pause between queries.`n"
    Write-Host "================================`n"
}
 
function vt_search {
    $Script:start = Get-Date
    $estimate_time = $Script:start + (New-TimeSpan -Seconds (((Get-Content $Script:input_file | Measure-Object -Line).Lines - 1) * 26))
    $estimate_elapsed = $estimate_time - $Script:start
    
    Write-Host "Domains:" (Get-Content $Script:input_file | Measure-Object -Line).Lines
    Write-Host "Estimated time: $estimate_elapsed`n"
    Write-Host "Info: Press Ctrl-C to interrupt querying`n"
    Write-Host "Querying...`n--------------------------------"

    If ((Get-Content $Script:input_file | Measure-Object -Line).Lines -eq 0) {
        Write-Host "`n*** Domains.txt empty ***" -ForegroundColor Yellow
        break
    }
    
    Get-Content $Script:input_file | ForEach-Object {
        $Script:cnt += 1
        $totalLines = (Get-Content $Script:input_file | Measure-Object -Line).Lines
        
        Write-Host "$Script:cnt/$totalLines :: $_" -NoNewline
 
        $url = "http://www.virustotal.com/vtapi/v2/url/report?apikey=" + $Script:api_key + "&resource=" + $_
 
        $query = Invoke-RestMethod -Method "POST" -Uri $url
         
        If ($query.response_code -eq 0) {
            Write-Host "... No report. Scanning" -NoNewLine
            $query = vt_scan $_
        } ELSEIF ((($Script:start.ToUniversalTime()) - [datetime]$query.scan_date) -gt (New-TimeSpan -Days 180)) {
            Write-Host "... Old report. Scanning" -NoNewLine
            $query = vt_scan $_
        }
 
        If ($query.positives -gt 0) {
            $Script:mal_hits += 1
            $Script:mal_urls[$query.url] = [ordered]@{"url"=$query.url; "hits"=$query.positives; "scan_date"=$query.scan_date; "permalink"=$query.permalink}
            Write-Host (" ... Malicious {0}/{1}" -f $query.positives, $query.total) -ForegroundColor Red
        } ELSEIF ($query.response_code -eq 0) {
            $Script:mal_urls[$query.resource] = [ordered]@{"url"=$query.resource; "hits"=$null; "scan_date"="No scan report"; "permalink"="Perform manual scan of URL";}
            Write-Host (" ... No scan report") -ForegroundColor Yellow
        } ELSEIF (($query.verbose_msg -eq "Scan request successfully queued, come back later for the report") -OR ($query.response_code -eq "-2")) {
            Write-Host "... Queued. Try again later" -ForegroundColor Yellow
            $Script:queued_urls.Add($scan_url)
            $Script:mal_urls[$query.resource] = [ordered]@{"url"=$query.resource; "hits"=$null; "scan_date"="Queued"; "permalink"="Check later: "+$query.permalink;}
       } ELSE {
            Write-Host " ... Clean" -ForegroundColor Green
        }
        
        If ($Script:cnt -lt $totalLines) {
            Start-Sleep -Seconds 27
        }
    }
}
 
function vt_scan($scan_url) {
    $Local:url = "https://www.virustotal.com/vtapi/v2/url/scan?apikey=" + $Script:api_key + "&url=" + $scan_url
    
    $scan_query = Invoke-RestMethod -Method Post -Uri $Local:url
    
    return $scan_query
}
 
function show_results {
    $Script:stop = Get-Date
    
    Write-Host "`n================================"
    Write-Host "`n--- Results ---"
    Write-Host "`nPositive malicious hits: " -NoNewLine
    
    If ($Script:mal_hits -gt 0) {
        Write-Host "$Script:mal_hits" -ForegroundColor Red
           
        Write-Host "`n--------------------------------`n"
        Write-Host "List of malicious URLs:"
        Write-Host "`nHits `t URL`n--- `t ---"
    
        ForEach ($k in $Script:mal_urls.Keys) {
            If ($Script:mal_urls.$k.hits -gt 0) {
                Write-Host $Script:mal_urls.$k.hits `t $k
            }
        }

        Write-Host "`n--------------------------------`n"
        Write-Host "List of queued URLs`n`nInfo: Check permalink in CSV later"
        Write-Host "`nURL `t Verbose Msg `n--- `t -----------"

        $Script:queued_urls | ForEach-Object {
            Write-Host $_
        }
    
        Write-Host "`n--------------------------------"
        Write-Host "`nList of URLS without scan reports"
        Write-Host "`nURL `n---"
    
        ForEach ($k in $Script:mal_urls.Keys) {
            If ($Script:mal_urls.$k.scan_date -eq "No scan report") {
                Write-Host $Script:mal_urls.$k.url
            }
        }
    } Else {
        Write-Host "$Script:mal_hits" -ForegroundColor Green
    }
    
    Write-Host "`n================================`n"
}


function save_file {
    $date = Get-Date -UFormat %Y.%m.%d
    $time = Get-Date -UFormat %H.%M.%S
    $elapsed = $Script:stop - $Script:start
    
    Write-Host "--- Export Results ----"
    
    If ($Script:mal_urls.Count -gt 0) {
        Write-Host ("`n`Saving malicous urls to $date`_$time`_malicious_urls.csv")
        Write-Host ("Directory: $Script:script_path")
        ForEach ($k in $Script:mal_urls.Keys) {
            New-Object -typename psobject -property $Script:mal_urls.$k | Select-Object hits,url,scan_date,permalink | Export-Csv -Path "$Script:script_path\$date`_$time`_malicious_urls.csv" -NoTypeInformation -Append
        }
    } Else {
        Write-Host "`n*** Nothing to export ***" -ForegroundColor Yellow
    }
    
    Write-Host "`n`n--------------------------------"
    
    Write-Host ("`nStart: $Script:start `t Stop: $Script:stop `nElapsed: $elapsed")
}

welcome
check_api_key
Try {
    vt_search
}
Catch {
	$_ | Out-File ".\error.txt"
}
Finally {
    show_results
    save_file
    pause
}
