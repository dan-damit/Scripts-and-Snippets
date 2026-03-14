# 1. Restore all default Windows power schemes
powercfg -restoredefaultschemes

# 2. Find the GUID for the built-in High Performance plan
$HighPerf = (powercfg -l | Select-String "High performance").ToString().Split()[3]

# 3. Set High Performance as the active plan
powercfg -setactive $HighPerf

# 4. Remove Ultimate Performance if it exists
$Ultimate = (powercfg -l | Select-String "Ultimate performance")
if ($Ultimate) {
    $UltimateGuid = $Ultimate.ToString().Split()[3]
    powercfg -delete $UltimateGuid
}