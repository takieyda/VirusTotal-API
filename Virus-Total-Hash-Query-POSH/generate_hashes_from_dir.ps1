# Generate Hashes from Directory script
# Place script file in directory with files to hash
# Version 0.1

function get_dir {
    $invoke = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $invoke.MyCommand.Path
}

$script_path = get_dir
$num_files = (Get-ChildItem -Recurse | Where-Object { -not $_.PSIsContainer }).Count - 1

$hashes = [ordered]@{}

function pause {
    Read-Host "`n`nPress Enter to continue." | Out-Null
}

function welcome {
    Write-Host "`n`n================================`n|      Generating Hashes       |`n================================"
    Write-Host "`nPath:  " -ForegroundColor Yellow -NoNewLine; Write-Host $script_path
    Write-Host "Files: " -ForegroundColor Yellow -NoNewLine; Write-Host $num_files"`n"
    Write-Host "================================`n"
}

function generate_hashes {
    $cnt = 0
    (Get-ChildItem -Recurse $script_path) | ForEach-Object {
        If (($_.Name -ne "generate_hashes_from_dir.ps1") -and (-not $_.PSIsContainer)) {
            $cnt += 1
            Set-Location $script_path
            $file_path = $_ | Resolve-Path -Relative
            $hash = (Get-FileHash -alg SHA1 -LiteralPath $file_path).Hash

            $hashes[$_] = [ordered]@{"filename"=$_.Name; "hash"=$hash; "alg"="SHA1"; "path"=$file_path;}
            Write-Host "$cnt... " -NoNewline
            If ($cnt -ge $num_files) {
                Write-Host "`n`n--------------------------------"
                Write-Host "`nFinished.`n" -ForegroundColor Green
            }
        }
    }

    Write-Host "================================`n"
}

function save_file {
    $date = Get-Date -UFormat %Y.%m.%d
    $time = Get-Date -UFormat %H.%M.%S
    
    Write-Host "--- Export Results ----"
    
    If ($hashes.Count -gt 0) {
        Write-Host ("`n`Saving hashes to $date`_$time`_hashes.csv")
        Write-Host ("Directory: $script_path")
        ForEach ($k in $hashes.Keys) {
            If ($k -ne "generate_hashes_from_dir.ps1") {
                New-Object -typename psobject -property $hashes.$k | Select filename,hash,alg,path | Export-Csv -Path "$Script:script_path\$date`_$time`_hashes.csv" -NoTypeInformation -Append
            }
        }
    } Else {
        Write-Host "`n*** Nothing to export ***" -ForegroundColor Yellow
    }
    
    Write-Host "`n`n--------------------------------"    
}

welcome
Try {
    generate_hashes
}
Catch {
	$_ | Out-File ".\error.txt"
}
Finally {
    save_file
    pause
}
