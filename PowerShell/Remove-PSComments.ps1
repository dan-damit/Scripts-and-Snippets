
#!/usr/bin/env pwsh
<#
.SYNOPSIS
Safely remove comments from a PowerShell script using the PowerShell parser.

.DESCRIPTION
Removes actual comment tokens from a .ps1 file using the PowerShell parser's token extents,
so '#' inside strings or here-strings are preserved. Optionally removes empty lines. Can preserve shebang and '#requires'.

.PARAMETER Path
Path to the input .ps1 file to clean.

.PARAMETER OutFile
Output path. If omitted and -InPlace is not used, cleaned content is written to stdout.

.PARAMETER InPlace
Overwrite the original file with the cleaned content.

.PARAMETER Backup
Create a backup '<original>.bak.ps1' before overwriting (only with -InPlace).

.PARAMETER KeepEmptyLines
Do not remove empty/whitespace-only lines after stripping comments.

.PARAMETER KeepShebang
Preserve a leading shebang (e.g., '#!/usr/bin/pwsh').

.PARAMETER KeepRequires
Preserve '#requires' directives.

.EXAMPLE
./psclean.ps1 -Path ./script.ps1 -OutFile ./script.cleaned.ps1

.EXAMPLE
./psclean.ps1 -Path ./script.ps1 -InPlace -Backup -KeepShebang -KeepRequires

.NOTES
Writes UTF-8 (no BOM). Works on Windows PowerShell 5.1 and PowerShell 7+.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, Position=0)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$Path,

    [Parameter()]
    [string]$OutFile,

    [Parameter()]
    [switch]$InPlace,

    [Parameter()]
    [switch]$Backup,

    [Parameter()]
    [switch]$KeepEmptyLines,

    [Parameter()]
    [switch]$KeepShebang,

    [Parameter()]
    [switch]$KeepRequires
)

# --- Utility: write error and exit non-zero for CLI ergonomics
function Stop-Cli([string]$Message, [int]$Code = 1) {
    Write-Error $Message
    exit $Code
}

# Validate output flags
if (-not $OutFile -and -not $InPlace) {
    Write-Verbose "No -OutFile or -InPlace specified; cleaned content will be written to stdout."
}

if ($OutFile -and $InPlace) {
    Stop-Cli "Specify either -OutFile or -InPlace, not both."
}

# Resolve input path and read content
$resolved = (Resolve-Path -LiteralPath $Path).Path
try {
    $text = [System.IO.File]::ReadAllText($resolved)
} catch {
    Stop-Cli "Failed to read file: $resolved. $_"
}

# Parse to collect tokens (including comments)
$tokens = $null
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$errors)

if ($errors -and $errors.Count -gt 0) {
    Write-Warning "Parser reported $($errors.Count) error(s). Proceeding to strip comments, but review output."
}

# Identify comment ranges to remove
$ranges = foreach ($t in $tokens) {
    if ($t.Kind -eq [System.Management.Automation.Language.TokenKind]::Comment) {
        $content = $t.Extent.Text

        # Preserve optional items
        if ($KeepShebang -and $t.Extent.StartOffset -eq 0 -and $content -match '^\s*#!') { continue }
        if ($KeepRequires -and $content -match '^\s*#\s*requires\b') { continue }

        [PSCustomObject]@{
            Start = $t.Extent.StartOffset
            End   = $t.Extent.EndOffset
        }
    }
}

# Remove comments by slicing from end to start
if ($ranges) {
    foreach ($r in ($ranges | Sort-Object Start -Descending)) {
        $len = $r.End - $r.Start
        $text = $text.Remove($r.Start, $len)
    }
}

# Remove empty/whitespace-only lines unless asked to keep them
if (-not $KeepEmptyLines) {
    $text = ($text -split "`r?`n" | Where-Object { $_ -notmatch '^\s*$' }) -join [Environment]::NewLine
}

# Output handling
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

if ($InPlace) {
    if ($Backup) {
        $bak = [System.IO.Path]::ChangeExtension($resolved, '.bak.ps1')
        try {
            [System.IO.File]::Copy($resolved, $bak, $true)
            Write-Verbose "Backup created: $bak"
        } catch {
            Stop-Cli "Failed to create backup: $bak. $_"
        }
    }

    if ($PSCmdlet.ShouldProcess($resolved, "Overwrite with cleaned content")) {
        try {
            [System.IO.File]::WriteAllText($resolved, $text, $utf8NoBom)
        } catch {
            Stop-Cli "Failed to write cleaned content to: $resolved. $_"
        }
    }
    # Exit 0 on success
    exit 0
}
elseif ($OutFile) {
    # If OutFile points to a directory, write using input leaf name
    $target = if (Test-Path -LiteralPath $OutFile -PathType Container) {
        Join-Path $OutFile (Split-Path $resolved -Leaf)
    } else {
        $OutFile
    }

    try {
        [System.IO.File]::WriteAllText($target, $text, $utf8NoBom)
        Write-Host "Cleaned file written: $target"
    } catch {
        Stop-Cli "Failed to write output: $target. $_"
    }
    exit 0
}
else {
    # Write to stdout (pipeline-friendly)
    $text
    exit 0
}
