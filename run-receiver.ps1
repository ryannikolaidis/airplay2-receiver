# Run the AirPlay2 Receiver
$receiverName = "WindowsAirPlay"
$networkGuid = "{0551E86D-92ED-4B98-A99E-365586D97305}"

Write-Host "============================================"
Write-Host "Starting AirPlay2 Receiver"
Write-Host "============================================"
Write-Host "Name: $receiverName"
Write-Host "Network: $networkGuid (10.0.0.22)"
Write-Host ""
Write-Host "The receiver will appear as '$receiverName' on iOS devices"
Write-Host ""
Write-Host "Press Ctrl+C to stop the receiver"
Write-Host "============================================"
Write-Host ""

# Run the receiver
.\ap2env\Scripts\python.exe ap2-receiver.py -m $receiverName -n $networkGuid
