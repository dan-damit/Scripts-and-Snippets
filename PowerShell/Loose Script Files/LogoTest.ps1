# Set console params
$scriptName = "DSCv3 Baseline Script"
$host.UI.RawUI.WindowTitle = $scriptName
$copyrightSymbol = [char]0x00A9
[console]::ForegroundColor = "DarkCyan"
Write-host "-----------------------------------------------"
Write-host "   Advantage Tech DSCv3 Configuration Script"
Write-host #
$ASCIILogo = "`n"+
    "`t            (((`n"+
    "`t           (((   *`n"+
    "`t          (((   ***`n"+
    "`t         (((     ***`n"+
    "`t        (((  ((   ***`n"+
    "`t       (((((((((   ***`n"+
    "`n"

Write-host "$ASCIILogo"
Write-host "      Copyright $copyrightSymbol 2025 Author: Dan.Damit"
Write-host "-----------------------------------------------"
Write-host #
Pause