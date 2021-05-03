# Virus Total Hash Query script
# Version 0.1
 
# $api_key_file = Get-Content $script_path\api_key.txt | Out-String | ConvertFrom-StringData
$api_key = "" # $api_key_file.api_key
$start = Get-Date
$stop = Get-Date

function get_dir {
    $invoke = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $invoke.MyCommand.Path
}

$script_path = get_dir

$input_file = Import-Csv $script_path"\hashes.csv"
$num_hashes = $input_file.Count
$cnt = 0

$mal_hits = 0
$mal_hashes = [ordered]@{}

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
    Write-Host "`n`n================================`n|    Virus Total Hash Query    |`n================================"
    Write-Host "`nInfo: Due to restrictions for public API use, `nInfo: there is a 26 second pause between queries.`n"
    Write-Host "================================`n"
}

function vt_search {
    $Script:start = Get-Date
    $estimate_time = $Script:start + (New-TimeSpan -Seconds ($num_hashes * 26))
    $estimate_elapsed = $estimate_time - $Script:start
    
    Write-Host "Hashes:" $num_hashes
    Write-Host "Estimated time: $estimate_elapsed`n"
    Write-Host "Info: Press Ctrl-C to interrupt querying`n"
    Write-Host "Querying...`n--------------------------------"

    If ($num_hashes -eq 0) {
        Write-Host "`n*** Hashes.csv empty ***" -ForegroundColor Yellow
        break
    }
    
    $Script:input_file | ForEach-Object {
        $Script:cnt += 1
        $totalLines = $num_hashes

        Write-Host "$Script:cnt/$totalLines :: $($_.filename)" -NoNewline
 
        $url = "http://www.virustotal.com/vtapi/v2/file/report?apikey=" + $Script:api_key + "&resource=" + $_.hash + "&allinfo=true"
 
        $query = Invoke-RestMethod -Method "GET" -Uri $url
 
        If ($query.positives -gt 0) {
            $Script:mal_hits += 1
            $Script:mal_hashes[$_.filename] = [ordered]@{"filename"=$_.filename; "hash"=$query.sha1; "path"=$_.path; "hits"=$query.positives; "scan_date"=$query.scan_date; "permalink"=$query.permalink}
            Write-Host (" ... Malicious {0}/{1}" -f $query.positives, $query.total) -ForegroundColor Red
        } ELSEIF ($query.response_code -eq 0) {
            $Script:mal_hashes[$_.filename] = [ordered]@{"filename"=$_.filename; "hash"=$_.hash; "path"=$_.path; "hits"=$null; "scan_date"="No scan report"; "permalink"="Perform local scan of file";}
            Write-Host (" ... No scan report.") -ForegroundColor Yellow
       } ELSE {
            Write-Host " ... Clean" -ForegroundColor Green
        }
        
        If ($Script:cnt -lt $totalLines) {
            Start-Sleep -Seconds 27
        }
    }
}
 
 
function show_results {
    $Script:stop = Get-Date
    
    Write-Host "`n================================"
    Write-Host "`n--- Results ---"
    Write-Host "`nPositive malicious hits: " -NoNewLine
    
    If ($Script:mal_hits -gt 0) {
        Write-Host "$Script:mal_hits" -ForegroundColor Red
        Write-Host "Please review the permalinks in the exported file." -ForegroundColor Yellow
           
        Write-Host "`n--------------------------------`n"
        Write-Host "List of malicious hashes:"
        Write-Host "`nHits `t Filename`n--- `t ---"
	} Else {
        Write-Host "$Script:mal_hits" -ForegroundColor Green
    }
    
	ForEach ($k in $Script:mal_hashes.Keys) {
		If ($Script:mal_hashes.$k.hits -gt 0) {
			Write-Host $Script:mal_hashes.$k.hits `t`t $Script:mal_hashes.$k.filename
		}
	}


	Write-Host "`n--------------------------------"
	Write-Host "`nList of hashes without scan reports:`n"

	ForEach ($k in $Script:mal_hashes.Keys) {
		If ($Script:mal_hashes.$k.scan_date -eq "No scan report") {
			Write-Host $Script:mal_hashes.$k.hash `t $Script:mal_hashes.$k.filename
		}
	}
    
    
    Write-Host "`n================================`n"
}


function save_file {
    $date = Get-Date -UFormat %Y.%m.%d
    $time = Get-Date -UFormat %H.%M.%S
    $elapsed = $Script:stop - $Script:start
    
    Write-Host "--- Export Results ----"
    
    If ($Script:mal_hashes.Count -gt 0) {
        Write-Host ("`n`Saving malicous hashes to $date`_$time`_malicious_hashes.csv")
        Write-Host ("Directory: $Script:script_path")
        ForEach ($k in $Script:mal_hashes.Keys) {
            New-Object -typename psobject -property $Script:mal_hashes.$k | Select hits,hash,filename,path,scan_date,permalink | Export-Csv -Path "$Script:script_path\$date`_$time`_malicious_hashes.csv" -NoTypeInformation -Append
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
