# This is used to help quell unwanted output during Execution
# Compiling with PS2EXE module.
if ($env:PS2EXE -eq 'True') {
    # Define log file path (optional: parameterize or timestamp)
    $logFile = Join-Path $env:TEMP 'MainOnboard.log'

    # Start a transcript to capture all output (including errors and write-host)
    $null = Start-Transcript -Path $logFile -Append -ErrorAction SilentlyContinue

    # Override Out-Host to redirect to the transcript instead of MessageBoxes
    function Out-Host {
        param([Parameter(ValueFromPipeline = $true)] $InputObject)
        process {
            foreach ($line in $InputObject) {
                Write-Output "$line"
            }
        }
    }
    function Write-Host {
        param(
            [Parameter(ValueFromRemainingArguments = $true)]
            $Text
        )
        Write-Output ($Text -join ' ')
    }
    function Out-Default {
        param([Parameter(ValueFromPipeline = $true)] $InputObject)
        process {
            foreach ($line in $InputObject) {
                Write-Output "$line"
            }
        }
    }
    Set-Item function:\Out-Host    -Value (Get-Command Out-Host).ScriptBlock -Force
    Set-Item function:\Out-Default -Value (Get-Command Out-Default).ScriptBlock -Force
    Set-Item function:\Write-Host  -Value (Get-Command Write-Host).ScriptBlock -Force
}