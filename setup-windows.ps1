# AirPlay 2 Receiver - Windows Setup Script
# This script checks prerequisites and guides through installation

$ErrorActionPreference = "Continue"
$logFile = "setup-log.txt"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $Message -ForegroundColor $Color
    $logMessage | Out-File $logFile -Append
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

Write-Log "=== AirPlay 2 Receiver - Windows Setup ===" "Cyan"
Write-Log ""

# Check Python
Write-Log "Checking Python installation..." "Yellow"
if (Test-Command "python") {
    $pythonVersion = python --version 2>&1
    Write-Log "✓ Found: $pythonVersion" "Green"
    python --version 2>&1 | Out-File $logFile -Append
} else {
    Write-Log "✗ Python not found!" "Red"
    Write-Log "  Install from: https://www.python.org/downloads/" "Yellow"
    Write-Log "  Make sure to check 'Add Python to PATH' during installation" "Yellow"
    $pythonOK = $false
}

# Check Pip
Write-Log ""
Write-Log "Checking pip..." "Yellow"
if (Test-Command "python") {
    try {
        $pipVersion = python -m pip --version 2>&1
        Write-Log "✓ Found: $pipVersion" "Green"
    } catch {
        Write-Log "✗ Pip not available!" "Red"
        Write-Log "  Install with: python -m ensurepip --upgrade" "Yellow"
    }
}

# Check Git
Write-Log ""
Write-Log "Checking Git..." "Yellow"
if (Test-Command "git") {
    $gitVersion = git --version
    Write-Log "✓ Found: $gitVersion" "Green"
} else {
    Write-Log "✗ Git not found!" "Red"
    Write-Log "  Install from: https://git-scm.com/download/win" "Yellow"
}

# Check FFmpeg
Write-Log ""
Write-Log "Checking FFmpeg..." "Yellow"
if (Test-Command "ffmpeg") {
    $ffmpegVersion = ffmpeg -version 2>&1 | Select-Object -First 1
    Write-Log "✓ Found: $ffmpegVersion" "Green"
} else {
    Write-Log "✗ FFmpeg not found!" "Red"
    Write-Log "  Install with: choco install ffmpeg -y" "Yellow"
    Write-Log "  Or download from: https://ffmpeg.org/download.html" "Yellow"
}

# Check Visual Studio Build Tools
Write-Log ""
Write-Log "Checking Visual Studio Build Tools..." "Yellow"
$clFound = $false
try {
    $clPath = where.exe cl.exe 2>&1
    if ($clPath -and $clPath -notmatch "Could not find") {
        Write-Log "✓ Found: cl.exe in PATH" "Green"
        $clFound = $true
    }
} catch {}

if (-not $clFound) {
    # Search in common locations
    $vsLocations = @(
        "C:\Program Files\Microsoft Visual Studio",
        "C:\Program Files (x86)\Microsoft Visual Studio"
    )
    foreach ($loc in $vsLocations) {
        if (Test-Path $loc) {
            $results = Get-ChildItem -Path $loc -Recurse -Filter "cl.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($results) {
                Write-Log "✓ Found: $($results.FullName)" "Green"
                Write-Log "  (Not in PATH but installed)" "Yellow"
                $clFound = $true
                break
            }
        }
    }
}

if (-not $clFound) {
    Write-Log "✗ Visual Studio Build Tools not found!" "Red"
    Write-Log "  Download from: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022" "Yellow"
    Write-Log "  Install 'Desktop development with C++' workload" "Yellow"
    Write-Log "  OR install PyAudio pre-compiled: pip install pipwin && pipwin install pyaudio" "Yellow"
}

# Check Bonjour (optional)
Write-Log ""
Write-Log "Checking Bonjour service (optional)..." "Yellow"
try {
    $bonjour = sc.exe query "Bonjour Service" 2>&1
    if ($bonjour -match "RUNNING") {
        Write-Log "✓ Bonjour service is running" "Green"
    } elseif ($bonjour -match "STOPPED") {
        Write-Log "⚠ Bonjour service is installed but stopped" "Yellow"
    } else {
        Write-Log "⚠ Bonjour not found (optional - uses zeroconf instead)" "Yellow"
    }
} catch {
    Write-Log "⚠ Bonjour not found (optional - uses zeroconf instead)" "Yellow"
}

# Check firewall
Write-Log ""
Write-Log "Checking Windows Firewall..." "Yellow"
try {
    $fwState = netsh advfirewall show allprofiles state | Select-String "State"
    Write-Log "✓ Firewall status:" "Green"
    $fwState | Out-String | Out-File $logFile -Append
    Write-Log "  Note: You may need to allow Python through firewall" "Yellow"
} catch {
    Write-Log "⚠ Could not check firewall status" "Yellow"
}

# Check ports
Write-Log ""
Write-Log "Checking ports 7000 and 5353..." "Yellow"
$ports = netstat -an | Select-String ":7000|:5353"
if ($ports) {
    Write-Log "⚠ Some ports may be in use:" "Yellow"
    $ports | Out-File $logFile -Append
} else {
    Write-Log "✓ Ports 7000 and 5353 are available" "Green"
}

# List network interfaces
Write-Log ""
Write-Log "Network interfaces:" "Yellow"
Write-Log "  (You'll need the GUID for one of these - run get-network-guid.ps1)" "Yellow"
$interfaces = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object Name, InterfaceDescription, ifIndex
foreach ($int in $interfaces) {
    Write-Log "  - $($int.Name): $($int.InterfaceDescription)" "Cyan"
}

# Check if we're in the right directory
Write-Log ""
if (Test-Path "ap2-receiver.py") {
    Write-Log "✓ Found ap2-receiver.py (in correct directory)" "Green"
} else {
    Write-Log "⚠ Not in airplay2-receiver directory" "Yellow"
}

# Check dependencies if requirements.txt exists
Write-Log ""
if (Test-Path "requirements.txt") {
    Write-Log "Checking Python dependencies..." "Yellow"
    Write-Log ""

    $requirements = Get-Content "requirements.txt"
    $missingPackages = @()

    foreach ($req in $requirements) {
        if ($req -match "^\s*#" -or $req -match "^\s*$") { continue }

        $packageName = ($req -split "==|>=|<=|>|<|~=")[0].Trim()

        try {
            $installed = python -m pip show $packageName 2>&1
            if ($installed -match "Name:") {
                Write-Log "  ✓ $packageName" "Green"
            } else {
                Write-Log "  ✗ $packageName (not installed)" "Red"
                $missingPackages += $packageName
            }
        } catch {
            Write-Log "  ✗ $packageName (not installed)" "Red"
            $missingPackages += $packageName
        }
    }

    if ($missingPackages.Count -gt 0) {
        Write-Log ""
        Write-Log "Missing packages: $($missingPackages -join ', ')" "Red"
        Write-Log "Install with: pip install -r requirements.txt" "Yellow"
    } else {
        Write-Log ""
        Write-Log "✓ All required packages are installed!" "Green"
    }
}

# Summary
Write-Log ""
Write-Log "=== Setup Summary ===" "Cyan"
Write-Log ""
Write-Log "Next steps:" "Yellow"
Write-Log "1. Install any missing dependencies listed above" "White"
Write-Log "2. Run: pip install -r requirements.txt" "White"
Write-Log "3. Run: powershell -ExecutionPolicy Bypass -File get-network-guid.ps1" "White"
Write-Log "4. Create config.json with your device name" "White"
Write-Log "5. Run: powershell -ExecutionPolicy Bypass -File run-receiver.ps1" "White"
Write-Log ""
Write-Log "Full log saved to: $((Resolve-Path $logFile).Path)" "Cyan"
Write-Log ""
Write-Log "For detailed instructions, see INSTALL.md" "Green"
