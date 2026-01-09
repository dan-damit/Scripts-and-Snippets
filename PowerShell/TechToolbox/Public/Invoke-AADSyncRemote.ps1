function Invoke-AADSyncRemote {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ComputerName,

        [Parameter()]
        [ValidateSet('Delta', 'Initial')]
        [string]$PolicyType = 'Delta',

        [Parameter()]
        [switch]$UseKerberos,

        [Parameter()]
        [switch]$EnableTranscript,

        [Parameter()]
        [ValidateSet(5985, 5986)]
        [int]$Port = 5985
    )

    # Prompt if missing
    if (-not $ComputerName -or [string]::IsNullOrWhiteSpace($ComputerName)) {
        $ComputerName = Read-Host -Prompt 'Enter the FQDN or hostname of the AAD Connect server'
    }
    $ComputerName = $ComputerName.Trim()

    # Transcript (optional)
    $transcriptPath = Join-Path -Path (Get-Location) -ChildPath ("AADSync_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
    if ($EnableTranscript) {
        try {
            Start-Transcript -Path $transcriptPath -ErrorAction Stop | Out-Null
            Write-Log -Level Info -Message "Transcript started: $transcriptPath"
        }
        catch {
            Write-Log -Level Warn -Message "Could not start transcript: $($_.Exception.Message)"
        }
    }

    Write-Log -Level Info -Message "Performing local pre-checks..."
    try {
        $resolved = Resolve-DnsName -Name $ComputerName -ErrorAction Stop
        $resolvedName = $resolved.NameHost ?? $resolved.Name
        Write-Log -Level Ok -Message "DNS resolution succeeded: $resolvedName"
    }
    catch {
        Write-Log -Level Warn -Message "DNS resolution failed for '$ComputerName': $($_.Exception.Message) — proceeding anyway."
    }

    # Build connection
    $sessionOption = New-PSSessionOption -OperationTimeout 180000
    $connectionUri = if ($Port -eq 5986) {
        "https://$ComputerName`:5986/wsman"
    }
    else {
        "http://$ComputerName`:5985/wsman"
    }

    # Create session
    $session = $null
    try {
        Write-Log -Level Info -Message "Creating remote session to $ComputerName on port $Port ..."
        if ($UseKerberos) {
            $session = New-PSSession -ComputerName $ComputerName -Authentication Kerberos -SessionOption $sessionOption -ErrorAction Stop
            Write-Log -Level Ok -Message "Session established using Kerberos."
        }
        else {
            $cred = Get-Credential -Message "Enter credentials with rights on $ComputerName"
            $session = New-PSSession -ConnectionUri $connectionUri -Credential $cred -SessionOption $sessionOption -ErrorAction Stop
            Write-Log -Level Ok -Message "Session established using supplied credentials."
        }
    }
    catch {
        Write-Log -Level Error -Message "Failed to create remote session: $($_.Exception.Message)"
        return
    }

    # Remote check + sync
    try {
        Write-Log -Level Info -Message "Checking ADSync module and service state on $ComputerName ..."
        $result = Invoke-Command -Session $session -ScriptBlock {
            $errors = @()

            try { Import-Module ADSync -ErrorAction Stop } catch {
                $errors += "ADSync module not found or failed to import: $($_.Exception.Message)"
            }

            $svc = Get-Service -Name 'ADSync' -ErrorAction SilentlyContinue
            if (-not $svc) {
                $errors += "ADSync service not found."
            }
            elseif ($svc.Status -ne 'Running') {
                $errors += "ADSync service state is '$($svc.Status)'; expected 'Running'."
            }

            if ($errors.Count -gt 0) {
                [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    PolicyType   = $using:PolicyType
                    Status       = 'PreCheckFailed'
                    Errors       = ($errors -join '; ')
                }
            }
            else {
                Start-ADSyncSyncCycle -PolicyType $using:PolicyType | Out-Null
                [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    PolicyType   = $using:PolicyType
                    Status       = 'SyncTriggered'
                    Errors       = ''
                }
            }
        }

        if ($result.Status -eq 'PreCheckFailed') {
            Write-Log -Level Error -Message "Remote pre-checks failed: $($result.Errors)"
            return
        }

        Write-Log -Level Ok -Message "Sync ($PolicyType) triggered successfully on $ComputerName."
        $result | Format-Table -AutoSize

    }
    finally {
        if ($session) {
            Remove-PSSession -Session $session -ErrorAction SilentlyContinue
            Write-Log -Level Info -Message "Remote session closed."
        }
        if ($EnableTranscript) {
            try { Stop-Transcript | Out-Null } catch {}
            Write-Log -Level Info -Message "Transcript saved: $transcriptPath"
        }
    }
}