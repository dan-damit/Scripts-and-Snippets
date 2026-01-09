function Get-WindowsKey {
    $key = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
    return $key
}
$ProductKey = Get-WindowsKey
Write-Output "Your Windows Product Key is: $ProductKey"