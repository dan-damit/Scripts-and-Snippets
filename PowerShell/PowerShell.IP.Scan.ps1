function Show-Spinner {
    $spinner = @('/','|','\','-')
    $i = 0
    while ($true) {
        Write-Host -NoNewline "`rScanning... $($spinner[$i % $spinner.Length])"
        Start-Sleep -Milliseconds 100
        $i++
    }
}

# Start spinner in background
$spinnerJob = Start-Job -ScriptBlock { Show-Spinner }

# Launch ping sweep jobs
$scanJobs = @()
1..254 | ForEach-Object {
    $ip = "192.168.1.$_"
    $scanJobs += Start-Job -ScriptBlock {
        if (Test-Connection -ComputerName $using:ip -Count 1 -Quiet) {
            "$using:ip is online"
        }
    }
}

# Wait for all scan jobs to finish
$scanJobs | ForEach-Object { Receive-Job -Job $_ -Wait }

# Stop spinner
Stop-Job -Job $spinnerJob
Remove-Job -Job $spinnerJob
Write-Host "`rScan complete!             "