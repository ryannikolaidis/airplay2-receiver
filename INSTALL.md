# AirPlay 2 Receiver - Windows Installation Guide

Complete installation guide for running the AirPlay 2 receiver on Windows with multi-room audio support.

## Prerequisites

### Required Software
- **Python 3.9 or later** - [Download](https://www.python.org/downloads/)
  - ⚠️ During installation, check "Add Python to PATH"
- **Git** - [Download](https://git-scm.com/download/win)
- **Visual C++ Build Tools** - Required for PyAudio compilation
  - Download [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)
  - Install "Desktop development with C++" workload
- **Chocolatey** (optional but recommended) - [Install](https://chocolatey.org/install)

### System Requirements
- Windows 10 or later
- Network interface with static IP recommended
- 2GB RAM minimum
- Administrator privileges for setup

---

## Installation Steps

### 1. Install System Dependencies

Install FFmpeg (required for audio decoding):

```powershell
# Using Chocolatey (recommended)
choco install ffmpeg -y

# OR download manually from https://ffmpeg.org/download.html
# Extract to C:\ffmpeg and add C:\ffmpeg\bin to PATH
```

### 2. Clone Repository

```powershell
git clone https://github.com/ryannikolaidis/airplay2-receiver.git
cd airplay2-receiver
```

### 3. Install Python Dependencies

```powershell
# Install all dependencies
pip install -r requirements.txt

# If PyAudio fails to install from PyPI, use pipwin:
pip install pipwin
pipwin install pyaudio
```

**Required Dependencies:**
- `av` (PyAV) - FFmpeg Python bindings
- `biplist` - Binary plist support
- `cryptography` - Encryption/decryption
- `ifaddr` - Network interface enumeration
- `netifaces` - Network interface info
- `pyaudio` - Audio playback
- `pycryptodomex` - Cryptographic operations
- `srptools` - SRP authentication
- `zeroconf` - mDNS/Bonjour broadcasting

### 4. Get Network Interface GUID

Windows requires the network interface GUID for binding. Run the helper script:

```powershell
powershell -ExecutionPolicy Bypass -File get-network-guid.ps1
```

**Example output:**
```
Network Interfaces:
[1] Ethernet - {AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE} - 192.168.1.100
[2] Wi-Fi - {12345678-90AB-CDEF-1234-567890ABCDEF} - 192.168.1.101
```

Copy the GUID (including braces) for the interface you want to use.

### 5. Configure Device Settings

Create `config.json` in the project root:

```json
{
  "device_name": "Windows AirPlay"
}
```

**Configuration Options:**
- `device_name` - Name that appears in iOS/macOS AirPlay menu

### 6. Run the Receiver

```powershell
# Using the launcher script (recommended)
powershell -ExecutionPolicy Bypass -File run-receiver.ps1

# OR run directly
python ap2-receiver.py -n "{YOUR-NETWORK-GUID}" -m "Windows AirPlay"
```

**Command Line Options:**
```
-n, --netiface    Network interface GUID (required on Windows)
-m, --mdns        Device name for mDNS broadcast
--debug           Enable debug logging
```

---

## Verification

### Check Receiver Status

1. **Bonjour Service Broadcasting**
   - Open iOS/macOS AirPlay menu
   - Look for your device name (e.g., "Windows AirPlay")

2. **Network Listener**
   - Receiver listens on port 7000 (HTTP)
   - Control port and data port assigned dynamically

3. **Test Playback**
   - Play audio from iOS device
   - Select Windows receiver from AirPlay menu
   - Volume control should work from iOS

### Multi-Room Audio

To test multi-room synchronization:

1. Start Windows receiver
2. Have another AirPlay 2 device available (HomePod, Sonos, etc.)
3. In iOS, select both devices simultaneously
4. Audio should play in sync across both devices

**Known Limitations:**
- Multi-room sync is best-effort without PTP (Precision Time Protocol)
- Windows doesn't support PTP natively
- Some drift may occur over long playback sessions

---

## Troubleshooting

### PyAudio Installation Fails

**Error:** `error: Microsoft Visual C++ 14.0 or greater is required`

**Solution:**
```powershell
# Install pre-compiled wheel
pip install pipwin
pipwin install pyaudio
```

### FFmpeg Not Found

**Error:** `av.codec.codec.Codec: No such codec: 'alac'`

**Solution:**
1. Verify FFmpeg installation: `ffmpeg -version`
2. If not installed: `choco install ffmpeg -y`
3. Restart terminal after installation

### Network Interface Issues

**Error:** `OSError: [Errno 10049] The requested address is not valid`

**Solution:**
1. Run `get-network-guid.ps1` to get correct GUID
2. Ensure interface is connected and has an IP address
3. Use the GUID (with braces) not the interface name

### Device Not Appearing in AirPlay Menu

**Checklist:**
- [ ] Receiver is running without errors
- [ ] Windows Firewall allows Python on private networks
- [ ] iOS device on same network as Windows PC
- [ ] Bonjour/mDNS not blocked by router
- [ ] Check receiver logs for errors

**Firewall Rule:**
```powershell
# Allow Python through Windows Firewall
New-NetFirewallRule -DisplayName "AirPlay Receiver" -Direction Inbound -Program "C:\Path\To\Python\python.exe" -Action Allow
```

### Volume Control Not Working

This should work automatically in this fork. If volume control from iOS doesn't work:

1. Verify receiver logs show `IAudioSessionControl` messages
2. Check Windows audio device is not muted
3. Ensure app volume is controlled, not system volume

### Audio Quality Issues

**Symptoms:** Crackling, dropouts, stuttering

**Solutions:**
- Increase buffer size: Edit `AIRPLAY_BUFFER` in `ap2-receiver.py`
- Check CPU usage (should be <20% during playback)
- Close other audio applications
- Use wired Ethernet instead of Wi-Fi if possible

### Multi-Room Sync Issues

**Symptoms:** Windows ahead or behind other AirPlay devices

**Notes:**
- Perfect sync requires PTP (not available on Windows)
- Some drift is normal without hardware sync
- Sync is best at playback start, may drift over time
- Network latency affects sync quality

---

## Advanced Configuration

### Custom Audio Buffer Size

Edit `ap2-receiver.py`:
```python
AIRPLAY_BUFFER = 8388608  # Default: 8MB (8192 packets)
# Increase for stability: 16777216 (16MB)
# Decrease for lower latency: 4194304 (4MB)
```

### Enable Debug Logging

```powershell
python ap2-receiver.py -n "{GUID}" -m "Windows AirPlay" --debug
```

Debug logs include:
- HTTP request/response headers
- RTP packet timing
- Audio frame processing
- Multi-room sync anchor points

### Running as Background Service

**Option 1: Task Scheduler**
1. Open Task Scheduler
2. Create Basic Task
3. Trigger: At startup
4. Action: Start a program
5. Program: `powershell.exe`
6. Arguments: `-ExecutionPolicy Bypass -File "C:\path\to\run-receiver.ps1"`

**Option 2: NSSM (Non-Sucking Service Manager)**
```powershell
# Install NSSM
choco install nssm -y

# Create service
nssm install AirPlayReceiver "C:\Python39\python.exe" "C:\path\to\ap2-receiver.py -n {GUID} -m 'Windows AirPlay'"

# Start service
nssm start AirPlayReceiver
```

---

## Architecture Notes

### Audio Pipeline
1. **RTP Reception** - Encrypted audio packets over UDP
2. **Decryption** - AES-CTR with session keys
3. **ALAC Decoding** - Using FFmpeg via PyAV
4. **Resampling** - Convert to target sample rate if needed
5. **Playback** - PyAudio to Windows audio device

### Multi-Room Sync
- **Anchor Timing** - iOS sends reference RTP timestamp and monotonic time
- **Latency Reporting** - Receiver reports buffer + device latency to iOS
- **Coordination** - iOS orchestrates playback start across all devices
- **Limitations** - Without PTP, devices use different time domains, causing drift

### Volume Control
- Uses Windows COM `IAudioSessionControl2` interface
- Controls per-application volume, not system volume
- Responds to iOS volume slider changes in real-time

---

## Project Structure

```
airplay2-receiver/
├── ap2-receiver.py           # Main entry point
├── ap2/
│   ├── connections/
│   │   ├── audio.py          # Audio processing and playback
│   │   ├── stream.py         # Stream management
│   │   ├── control.py        # RTP control channel
│   │   └── event.py          # Event channel
│   ├── pairing/
│   │   ├── hap.py           # HomeKit Accessory Protocol
│   │   └── srp.py           # Secure Remote Password auth
│   ├── playfair.py          # FairPlay DRM handling
│   └── utils.py             # Utility functions (volume control)
├── config.json              # Configuration file
├── get-network-guid.ps1     # Helper script
├── run-receiver.ps1         # Launcher script
├── requirements.txt         # Python dependencies
└── INSTALL.md              # This file
```

---

## Credits

Based on [openairplay/airplay2-receiver](https://github.com/openairplay/airplay2-receiver)

**Windows-Specific Improvements:**
- Volume control via IAudioSessionControl2
- PyAV 10.0.0 compatibility
- Configuration file support
- Installation documentation

---

## License

See [LICENSE](LICENSE) file in repository.

---

## Support

For issues specific to this Windows fork:
- GitHub Issues: https://github.com/ryannikolaidis/airplay2-receiver/issues

For general AirPlay 2 protocol questions:
- Upstream repo: https://github.com/openairplay/airplay2-receiver
