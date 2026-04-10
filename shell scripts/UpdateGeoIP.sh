:local countries {"BD";"CN";"RU";"IR";"IQ";"KP";"SY";"AF";"BY";"VE";"SD";"PK";"TR";"BR";"IN";"HK";"SG";"TH"}
:local baseUrl "https://mikrotik-geoip.com/free/?version=7&family=ipv4&type=firewall&country="
:local folder "/GeoIP/"
:local listName "MikroTik-GeoIP"

/ip firewall address-list remove [find list=$listName]

:foreach c in=$countries do={

    :local fileName ("GeoIP-" . $c . ".rsc")
    :local fullPath ($folder . $fileName)

    /tool/fetch url=($baseUrl . $c) output=file dst-path=$fullPath
    :delay 2

    /import file-name=$fullPath
    :delay 1
}
