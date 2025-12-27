# Get network interface GUID for the active Ethernet adapter
$output = "..\network-guid.txt"

"=== Network Interface GUID ===" | Out-File $output
"Date: $(Get-Date)" | Out-File $output -Append
"" | Out-File $output -Append

# Get active network adapters with IPv4 addresses
"Active Network Adapters:" | Out-File $output -Append
Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | ForEach-Object {
    $adapter = $_
    $ip = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue

    if ($ip) {
        "" | Out-File $output -Append
        "Name: $($adapter.Name)" | Out-File $output -Append
        "Description: $($adapter.InterfaceDescription)" | Out-File $output -Append
        "MAC: $($adapter.MacAddress)" | Out-File $output -Append
        "IP: $($ip.IPAddress)" | Out-File $output -Append
        "GUID: $($adapter.InterfaceGuid)" | Out-File $output -Append
        "---" | Out-File $output -Append
    }
}

"" | Out-File $output -Append
"" | Out-File $output -Append
"To run the receiver, use the GUID from the adapter with IP 10.0.0.22" | Out-File $output -Append
"Example command:" | Out-File $output -Append
"  .\ap2env\Scripts\python.exe ap2-receiver.py -m WindowsAirPlay -n {YOUR-GUID-HERE}" | Out-File $output -Append

Write-Host "Network info saved to: $((Resolve-Path $output).Path)"
Write-Host ""
Write-Host "Check the file for your network interface GUID (use the one with IP 10.0.0.22)"
