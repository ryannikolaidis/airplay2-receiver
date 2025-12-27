$output = "airplay2-env-check.txt"

"=== Environment Check for AirPlay2 Server ===" | Out-File $output
"Date: $(Get-Date)" | Out-File $output -Append
""  | Out-File $output -Append

"=== Python Version ===" | Out-File $output -Append
try { python --version 2>&1 | Out-File $output -Append } catch { "Python not found" | Out-File $output -Append }
"" | Out-File $output -Append

"=== Pip Version ===" | Out-File $output -Append
try { python -m pip --version 2>&1 | Out-File $output -Append } catch { "Pip not found" | Out-File $output -Append }
"" | Out-File $output -Append

"=== Port Check (7000, 5353) ===" | Out-File $output -Append
$ports = netstat -an | Select-String ":7000|:5353"
if ($ports) { $ports | Out-File $output -Append } else { "Ports 7000 and 5353 are available" | Out-File $output -Append }
"" | Out-File $output -Append

"=== Firewall Status ===" | Out-File $output -Append
netsh advfirewall show allprofiles state | Out-File $output -Append
"" | Out-File $output -Append

"=== Bonjour Service ===" | Out-File $output -Append
try { sc.exe query "Bonjour Service" 2>&1 | Out-File $output -Append } catch { "Bonjour not found" | Out-File $output -Append }
"" | Out-File $output -Append

"=== Git Version ===" | Out-File $output -Append
try { git --version 2>&1 | Out-File $output -Append } catch { "Git not found" | Out-File $output -Append }
"" | Out-File $output -Append

"=== Python Packages ===" | Out-File $output -Append
try { python -m pip list 2>&1 | Out-File $output -Append } catch { "Cannot list packages" | Out-File $output -Append }
"" | Out-File $output -Append

"=== Network Interfaces ===" | Out-File $output -Append
ipconfig /all | Out-File $output -Append
"" | Out-File $output -Append

"=== Visual Studio Build Tools ===" | Out-File $output -Append
try { where.exe cl.exe 2>&1 | Out-File $output -Append } catch { "cl.exe not found" | Out-File $output -Append }
"" | Out-File $output -Append

"=== Python Import Test ===" | Out-File $output -Append
try {
    python -c "import sys; print(f'Python: {sys.executable}'); print(f'Version: {sys.version}'); import pip; print('pip OK')" 2>&1 | Out-File $output -Append
} catch {
    "Python import failed" | Out-File $output -Append
}

Write-Host "Done! Output in: $((Resolve-Path $output).Path)"
