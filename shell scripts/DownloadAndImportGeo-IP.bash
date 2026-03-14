/system script set UpdateGeoIP source="

# --- CONFIG ---
:local countries {\"BD\";\"CN\";\"RU\";\"IR\";\"IQ\";\"KP\";\"SY\";\"AF\";\"BY\";\"VE\";\"SD\";\"PK\";\"TR\";\"BR\";\"IN\";\"HK\";\"SG\";\"TH\"}
:local baseUrl \"https://mikrotik-geoip.com/free/?version=7&family=ipv4&type=firewall&country=\"
:local folder \"/GeoIP/\"

# --- MAIN LOOP ---
:foreach c in=\$countries do={

    :local fileName (\"GeoIP-\" . \$c . \".rsc\")
    :local fullPath (\$folder . \$fileName)
    :local ok true

    :log info (\"GeoIP: Updating \" . \$c)

    :do {

        # Fetch file
        /tool/fetch url=(\$baseUrl . \$c) output=file dst-path=\$fullPath

        :delay 2

        # Check file exists
        :local f [/file find name=\$fileName]
        :if (\$f = \"\") do={
            :log warning (\"GeoIP: \" . \$c . \" file missing after fetch.\")
            :set ok false
            :error \"skip\"
        }

        # Read first line to detect HTML or errors
        :local firstLine [/file get \$f contents]
        :if ([:find \$firstLine \"<html>\"] != nil) do={
            :log error (\"GeoIP: \" . \$c . \" returned HTML (rate limit). Skipping.\")
            :set ok false
            :error \"skip\"
        }

        :if ([:find \$firstLine \"<!DOCTYPE\"] != nil) do={
            :log error (\"GeoIP: \" . \$c . \" returned HTML (blocked). Skipping.\")
            :set ok false
            :error \"skip\"
        }

        :if ([:find \$firstLine \"Cloudflare\"] != nil) do={
            :log error (\"GeoIP: \" . \$c . \" returned Cloudflare page. Skipping.\")
            :set ok false
            :error \"skip\"
        }

        # Validate file size
        :local size [/file get \$f size]
        :if (\$size < 200) do={
            :log warning (\"GeoIP: \" . \$c . \" file too small (\" . \$size . \" bytes). Skipping.\")
            :set ok false
            :error \"skip\"
        }

    } on-error={
        :log warning (\"GeoIP: \" . \$c . \" skipped due to error.\")
    }

    # --- IMPORT MUST BE OUTSIDE THE DO BLOCK ---
    :if (\$ok = true) do={
        :log info (\"GeoIP: Importing \" . \$c)
        /import file-name=\$fullPath
        :delay 1
    }

}

:log info \"GeoIP: All updates complete.\"
"