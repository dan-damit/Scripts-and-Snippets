;------------------------------------------------------------
; AdvTech Onboarding Installer
;------------------------------------------------------------

RequestExecutionLevel admin

; Temporarily disable silent mode for debugging
SilentInstall normal

Name "Schick 33 Integration (Eaglesoft)"
OutFile "Schick_Integration.exe"
Icon "AdvTechLogo.ico"
VIProductVersion "1.1.0.0"  ; must be in a 4-part numeric format
VIAddVersionKey "FileVersion" "1.1.0.0"
VIAddVersionKey "ProductName" "Schick 33 Integration"
VIAddVersionKey "ProductVersion" "1.1.0.0"
VIAddVersionKey "FileDescription" "Schick 33 Sensor Eaglesoft Integration"
VIAddVersionKey "CompanyName" "Advantage Technologies"
VIAddVersionKey "LegalCopyright" "© 2025 Advantage Technologies"
VIAddVersionKey "OriginalFilename" "Schick_Integration.exe"

InstallDir "$TEMP\AdvTech_SchickIntegration"

Section "Install Files" SecInstall
    SetOutPath "$INSTDIR"
    DetailPrint "Installing to: $INSTDIR"
    
    File "setup.exe"
	File "Setup.ini"
    File "AdvTechLogo.ico"
    File "0x0409.ini"
	File "Data1.cab"
	File "instmsia.exe"
	File "instmsiw.exe"
	File "ISScript8.msi"
	File "Patterson - Schick Integration.msi"
    
    ; Create a debug marker file for verification.
    FileOpen $0 "$INSTDIR\debug.txt" w
    FileWrite $0 "Extraction successful: $INSTDIR"
    FileClose $0
SectionEnd

; Launch Program

Section "Launch Onboard" SecLaunch
    DetailPrint "Launching: $INSTDIR\setup.exe"
    ExecShell "open" "$INSTDIR\setup.exe"
SectionEnd

Function .onInstSuccess
    Quit
FunctionEnd