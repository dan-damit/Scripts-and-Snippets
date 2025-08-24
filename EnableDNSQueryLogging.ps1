# Author: Dan.Damit
# e: Dan@thedamits.com
#
# Description: This script defines the DNS log filepath 
# and enabled DNS query logging on Windows Server DNS.
#
# Date Created: 20241022
# Date Last Modified: 20250220
#
#--------------------------------------------------------
#
# Define the DNS server and log file path
$dnsServer = "localhost"
$logFilePath = "C:\dns_logs\dns.log"

# Import the DNS server module
Import-Module DNSServer

# Enable DNS query logging
Set-DnsServerDiagnostics -ComputerName $dnsServer -QueryLogging $true

# Set the log file path
Set-DnsServerDiagnostics -ComputerName $dnsServer -LogFilePath $logFilePath

# Confirm the settings
Get-DnsServerDiagnostics -ComputerName $dnsServer