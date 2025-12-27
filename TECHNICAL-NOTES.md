# Tech Spec: Windows AirPlay 2 Audio Receiver (Multi‑Room / Multi‑Target Compatible)

**Document owner:** Staff+ Eng (research spike deliverable)  
**Last updated:** 2025-12-26  
**Target OS:** Windows 10/11 (x64)  
**Scope:** **Audio only** (no video, no photo, no mirroring)

---

## 0) Executive summary

We want a **simple executable** that runs on a Windows machine and appears as an **AirPlay 2 audio destination** to iOS so that:

1. iOS can stream audio to the Windows machine using native AirPlay output selection, and  
2. **critically:** the user can **select this receiver together with other AirPlay 2 speakers** (multi‑room / multi‑target playback).

AirPlay 2 is **not publicly specified** by Apple as an open protocol. Practical implementations rely on **reverse engineering** and/or **MFi** (Apple’s licensing program). For an internal tool / prototype, the fastest path is to build on an existing open-source reverse‑engineered receiver and harden/package it for Windows.

This spec proposes:
- **MVP implementation** by forking **`openairplay/airplay2-receiver`** (Python), because it already implements key AirPlay 2 receiver components including HomeKit pairing and FairPlay v3 auth/decryption and supports both buffered and realtime audio streams.  
- Packaging it into a **single Windows executable** and installing it as a **Windows Service** to run at startup.
- Ensuring iOS treats it as a **multi-room capable AirPlay 2 target** by advertising the correct **mDNS `features` bitmask** and implementing **buffered audio + PTP-driven scheduling** (at least “good enough” for stable multi-target playback).

---

## 1) Goals & non‑goals

### Goals
- **G1:** Windows machine appears in iOS AirPlay audio output list.
- **G2 (critical):** iOS can select this receiver **alongside other AirPlay 2 devices** for multi‑target streaming.
- **G3:** Reliable audio playback from common iOS apps (Music, Spotify, YouTube, Safari, etc.).
- **G4:** Delivered as a **simple executable** that can run at startup (Windows Service preferred).
- **G5 (bonus):** Same codebase runs on macOS with minimal changes.

### Non‑goals
- Video / photo / screen mirroring.
- Remote control protocols (DACP/MRP), metadata/artwork (unless essentially free), Siri/HomePod features.
- “Perfect” sub‑millisecond sync in v1 (design for improvement, ship stable first).

---

## 2) Constraints and realities

### 2.1 “Open specs” status
There is **no official public AirPlay 2 specification** to implement like an RFC. Publicly available information is primarily:
- Reverse-engineered notes (e.g., AirPlay 2 Internals by Emanuele Cozzi).
- Unofficial AirPlay (mostly AirPlay 1 / legacy) protocol writeups, still useful for RTSP/RTP patterns.
- Open-source implementations that embody the de-facto behavior.

### 2.2 Legal / licensing (engineering risk note)
If this is intended for broad commercial distribution, you should assume you may need to engage Apple’s **MFi program** for compliant authentication. The open-source ecosystem tends to avoid true MFi hardware authentication (because it requires proprietary hardware/modules). For internal prototyping and controlled environments, RE-based implementations can be acceptable depending on your org’s risk posture.

---

## 3) Key requirement: multi‑target streaming (AirPlay 2 multi‑room)

### 3.1 What “multi‑room” means operationally
From the receiver’s perspective, multi‑target streaming typically means:
- iOS will establish **separate sessions** to each selected receiver.
- iOS will attempt to keep them aligned in time by using capabilities the receiver advertises (notably buffered audio, timing synchronization/PTP, and “tight sync” behaviors).

So the receiver must:
1. Be **discoverable** as an AirPlay 2 target, and  
2. Advertise capabilities such that iOS considers it eligible for multi-room/multi-target selection, and  
3. Implement enough of **buffered playback + timing** that the experience is not obviously broken.

### 3.2 mDNS `features` bitmask is the gating factor
AirPlay 2 senders inspect `_airplay._tcp` and `_raop._tcp` mDNS TXT records; **`features` is the most important record** controlling receiver capabilities.

AirPlay 2 Internals documents:
- `features` is a 64‑bit bitfield encoded as **two 32‑bit hex values** separated by a comma.
- A **minimal set of features for multi‑room support**, and the corresponding bitmask encoding.

The documented minimal set for multi‑room support is:
- `SupportsAirPlayAudio` (bit 9)  
- `AudioRedundant` (bit 11)  
- `HasUnifiedAdvertiserInfo` (bit 30)  
- `SupportsBufferedAudio` (bit 40)  
- `SupportsPTP` (bit 41)  
- `SupportsUnifiedPairSetupAndMFi` (bit 51)  

The corresponding minimal mask: `0x8030040000a00`, advertised as:  
`features=0x40000a00,0x80300`

**This is critical to satisfy G2.**

---

## 4) Proposed solution and alternatives

### 4.1 Recommended approach (simplicity + fastest path)
**Fork and productize:** `openairplay/airplay2-receiver`.

Reasons:
- Already implements major AirPlay 2 receiver pieces:
  - HomeKit transient/non‑transient pairing (SRP/Curve25519/ChaCha20‑Poly1305)
  - FairPlay (v3) authentication + AES key handling
  - Buffered + realtime audio receive
  - mDNS service publication
  - Codec decode for ALAC/AAC/OPUS/PCM
- Provides Windows setup/run guidance (Python + dependencies).

**Strategy:** keep the protocol core as close to upstream as possible, and add a thin Windows product layer:
- configuration
- packaging into single EXE
- service wrapper
- robust logging/diagnostics
- minimal code changes to ensure correct multi-room `features` and scheduling behavior

### 4.2 Alternatives (not chosen for MVP)
- **Shairport Sync (C):** can be built as an AirPlay 2 player with limitations, but is mainly targeted at Linux/BSD; Windows would be a porting project (audio backends, build chain). Good as a behavior reference and for architecture inspiration.
- **goplay2 (Go):** AirPlay 2 speaker in Go; documentation lists Linux targets; Windows viability is not a documented goal and would be experimental.
- **SteeBono/airplayreceiver (C#):** .NET receiver claims AirPlay 2 mirroring/audio; may still require significant codec and protocol effort; potential longer-term option if you want native Windows service integration.

---

## 5) Architecture

### 5.1 Component diagram (logical)

1. **mDNS Advertiser/Responder**
   - Publishes `_airplay._tcp` and `_raop._tcp` with correct TXT records (`features` in particular).

2. **Control Plane (RTSP-like server over TCP)**
   - Handles session setup: `OPTIONS`, `ANNOUNCE`, `SETUP`, `RECORD`, `FLUSH`, `TEARDOWN`
   - Handles pairing/auth endpoints: `/pair-setup`, `/pair-verify`, `/fp-setup` (and possibly `/auth-setup`)

3. **Pairing + Authentication**
   - HomeKit pairing
   - FairPlay v3 handshake (to decrypt session keys and/or stream keys)

4. **Streaming Plane (RTP/RTCP)**
   - Receives audio over RTP (UDP)
   - RTCP for stats/timing
   - Optional RFC2198 redundancy if enabled

5. **Clock / Timing / Sync**
   - PTP client/server behavior sufficient for scheduling (software timestamps MVP)
   - Playback scheduler mapping sender timestamps/anchors to local playout

6. **Audio pipeline**
   - decrypt -> decode -> jitter buffer -> resample/drift correction -> WASAPI output

7. **Host integration**
   - config, logs, service install/uninstall, diagnostics

---

## 6) Protocol behaviors we must support (audio-only)

### 6.1 Service discovery
- iOS uses mDNS/Bonjour service discovery.
- AirPlay 2 currently uses `_airplay._tcp` as the main service.
- The control plane typically runs on **TCP 7000** but may run on any port advertised in mDNS TXT records.

### 6.2 Authentication method precedence (important)
AirPlay 2 Internals documents sender auth method precedence as:
1. MFi (if `Authentication_8` or `SupportsUnifiedPairSetupAndMFi` is enabled)
2. FairPlay (if `Authentication_4` is enabled)
3. RSA (if `Authentication_1` is enabled; documented as effectively disabled by Apple)

It also notes a behavioral quirk: when only `SupportsUnifiedPairSetupAndMFi` is enabled (without `Authentication_8`), the sender may pass checks but not initiate auth setup (a “logic bug” that could change in future iOS versions).

**Practical implication:** implement FairPlay v3 and HomeKit pairing. Do not depend on quirks for long-term reliability.

### 6.3 RTP encryption (audio payload)
AirPlay 2 Internals documents RTP payload encryption using **ChaCha20‑Poly1305 AEAD** (RFC 7539) for audio packets in at least some modes. The receiver must derive keys during session setup and decrypt payloads accordingly.

---

## 7) Windows-specific requirements

### 7.1 Ports and firewall
Open or allow inbound on:
- UDP 5353 (mDNS)
- TCP 7000 (control plane) or configured port
- UDP 319/320 (PTP timing) — if implemented
- UDP range for RTP/RTCP negotiated during `SETUP` (recommend configurable range, e.g. 50000–50100)

### 7.2 Audio output
- MVP: **WASAPI shared mode** (default device)
- Allow selecting output device by friendly name/ID in config
- Provide volume behavior:
  - simplest: honor OS default volume
  - optional: “soft volume” scaling in PCM domain

### 7.3 Run at startup
Support both:
- **Windows Service** (recommended)
- Scheduled Task (fallback; user login required)

---

## 8) Implementation plan (phased)

### Phase 0: Prove multi‑target works (risk burn-down)
- Run upstream `airplay2-receiver` on Windows using its documented instructions.
- Validate:
  - iOS sees the receiver in AirPlay list
  - iOS can select it **together with** another AirPlay 2 speaker
- Capture traffic in Wireshark to verify:
  - mDNS `features` values
  - session endpoints used by iOS
  - RTP encryption mode and codec negotiation

### Phase 1: Productize (single EXE + service)
- Introduce `config.json` (see §9)
- Add structured logging (file + console)
- Package as single EXE (PyInstaller or Nuitka)
- Add service install/uninstall commands
- Provide a “diagnostics” mode: show bound NIC, published TXT records, open ports, audio device list

### Phase 2: Sync quality (buffered + PTP + drift correction)
- Ensure advertised multi-room `features` align with implementation (buffered audio + PTP supported)
- Implement PTP (software timestamps MVP)
- Add drift correction:
  - small adaptive resampling ratio OR
  - frame stuffing/drop with minimal artifacts
- Add “sync health” logging metrics

---

## 9) Configuration spec (`config.json`)

Example:

```json
{
  "name": "My Windows Speaker",
  "interface": {
    "bind_ip": "192.168.1.50",
    "netiface_guid": "{02681AC0-AD52-4E15-9BD6-8C6A08C4F836}"
  },
  "device": {
    "device_id": "AA:BB:CC:DD:EE:FF",
    "model": "WinAirPlay2Speaker1,1"
  },
  "network": {
    "control_port": 7000,
    "rtp_port_range": [50000, 50100]
  },
  "features": {
    "enable_rfc2198_redundancy": false,
    "enable_stream_connections": true,
    "multi_room_minimal_features": true
  },
  "sync": {
    "enable_ptp": true,
    "target_latency_ms": 2000
  },
  "audio": {
    "output_device": "default",
    "initial_volume_db": 0.0
  },
  "logging": {
    "level": "INFO",
    "path": "C:\\ProgramData\\WinAirPlay2\\logs\\receiver.log"
  }
}
```

Notes:
- `multi_room_minimal_features=true` should force `features=0x40000a00,0x80300` unless overridden.
- Device identity (`device_id`, pairing keys) must be stable across restarts or iOS will behave inconsistently.

---

## 10) mDNS advertisement spec

### 10.1 Required services
Publish both:
- `_airplay._tcp.local.` (AirPlay 2 primary discovery)
- `_raop._tcp.local.` (audio discovery; still relevant)

### 10.2 Required `_airplay._tcp` TXT records (minimal)
At minimum:
- `deviceid`
- `model`
- `protovers`
- `srcvers`
- `features` (**must include multi-room minimal set for G2**)

### 10.3 Correct encoding for `features`
`features` is 64-bit, encoded as two 32-bit hex values separated by comma, with lower 32 bits first.

Example documented behavior:
- features set `0x1111111122222222` is declared as `"0x22222222,0x11111111"`.

Multi-room minimal features:
- 64-bit mask: `0x8030040000a00`
- Advertised as: `features=0x40000a00,0x80300`

### 10.4 Representative code: compute and publish `features`

```python
def pack_features(low32: int, high32: int) -> str:
    return f"0x{low32:08X},0x{high32:X}"

# Multi-room minimal features from AirPlay 2 Internals:
features = pack_features(0x40000A00, 0x80300)
```

Then publish using Zeroconf/Bonjour (or native Windows mDNS).

---

## 11) Control plane server (RTSP-like) spec

### 11.1 Server responsibilities
- Listen on configured TCP port (default 7000).
- Parse RTSP-like requests (start-line, headers, body).
- Maintain per-session state:
  - session id
  - negotiated ports/transport
  - derived keys (pairing/auth + stream keys)
  - codec settings
  - latency/anchor timing parameters

### 11.2 Minimal routing table

- `OPTIONS`
- `ANNOUNCE` (codec/key parameters)
- `SETUP` (transport/ports; may carry encrypted key material)
- `RECORD` (start)
- `FLUSH` (stop/seek)
- `TEARDOWN` (close)
- `POST /pair-setup`
- `POST /pair-verify`
- `POST /fp-setup` (FairPlay)
- (Optional) `POST /auth-setup` (MFi; likely not implemented)

### 11.3 Representative handler skeleton

```python
class AirPlayController:
    def options(self, req): ...
    def pair_setup(self, req): ...
    def pair_verify(self, req): ...
    def fp_setup(self, req): ...
    def announce(self, req): ...
    def setup(self, req): ...
    def record(self, req): ...
    def flush(self, req): ...
    def teardown(self, req): ...
```

---

## 12) Streaming plane spec (RTP/RTCP)

### 12.1 RTP receive
- Bind UDP ports negotiated in `SETUP`.
- Parse RTP headers, reorder by sequence number.
- Decrypt payload (ChaCha20‑Poly1305 in documented mode) using keys/nonce/AAD rules described in reverse-engineered notes.
- Decode frames to PCM.

### 12.2 Jitter buffer (minimal)
- Heap-based reorder buffer
- Start playout only when buffered >= target latency (buffered mode)
- Implement packet-loss policy (wait vs skip) with configurable thresholds

Representative minimal jitter buffer:

```python
import heapq
from dataclasses import dataclass

@dataclass(order=True)
class RtpPacket:
    seq: int
    ts: int
    payload: bytes

class JitterBuffer:
    def __init__(self, max_packets=512):
        self._heap = []
        self._max = max_packets
        self._expected = None

    def push(self, pkt: RtpPacket):
        if len(self._heap) < self._max:
            heapq.heappush(self._heap, pkt)

    def pop_in_order(self):
        if self._expected is None and self._heap:
            self._expected = self._heap[0].seq
        if not self._heap:
            return None
        if self._heap[0].seq == self._expected:
            pkt = heapq.heappop(self._heap)
            self._expected = (self._expected + 1) & 0xFFFF
            return pkt
        return None
```

### 12.3 RTCP
- Consume RTCP reports relevant to timing and stats.
- Provide timing feedback if needed by sender (implementation-dependent; upstream receiver already implements RTCP in some form).

---

## 13) Timing & sync spec (PTP + scheduler)

### 13.1 Why timing matters for G2
When iOS streams to multiple receivers, it relies on timing capabilities (buffered playback + PTP) to keep endpoints aligned.

### 13.2 MVP PTP (software timestamps)
- Listen on UDP 319/320.
- Support enough message types to estimate offset/delay and compute a stable “PTP-ish now()”:
  - Sync / Follow_Up
  - Delay_Req / Delay_Resp
- Maintain filtered estimates:
  - offset
  - path delay

### 13.3 Playback scheduler
- Map RTP timestamps (or announced anchors) to target playout times in the local clock domain.
- Maintain target latency (e.g., 2000 ms buffered).
- Compensate drift:
  - Preferred: micro-resampling (slightly adjust playback rate)
  - Simpler fallback: occasional frame stuffing/dropping (more artifacts)

---

## 14) Audio pipeline spec (Windows)

### 14.1 Decode & resample
- Decode to PCM float32 or int16
- Resample to match output device sample rate (if needed)
- Apply volume scaling (optional)

### 14.2 Output
- WASAPI shared mode
- Handle device changes gracefully (default device switch)

---

## 15) Packaging & deployment

### 15.1 Single EXE packaging
Choose one:
- **PyInstaller** `--onefile` for fastest time-to-exe
- **Nuitka** if you want better performance and more native packaging characteristics

Bundle:
- Python runtime + dependencies
- Any native DLLs needed (e.g., PortAudio / codec libs)
- Default config template

### 15.2 Windows Service
Provide CLI:
- `WinAirPlay2Receiver.exe install-service --config C:\ProgramData\WinAirPlay2\config.json`
- `WinAirPlay2Receiver.exe uninstall-service`
- `WinAirPlay2Receiver.exe run --config ...`

Implementation options:
- `pywin32` service class in Python (tight integration)
- External wrapper (e.g., NSSM / WinSW) that runs the EXE (simpler installer story)

---

## 16) Testing & validation

### 16.1 Acceptance tests
1. **Discovery:** receiver appears in iOS AirPlay list.
2. **Single-stream playback:** audio plays reliably.
3. **Multi-target playback (critical):** iOS can select receiver + another AirPlay 2 speaker simultaneously and both play.
4. **Stability:** 30-minute playback without dropouts.
5. **Sync sanity:** multi-target echo is within acceptable bounds (human-perceived).

### 16.2 Observability
- Structured logs with session ids
- Optional local metrics endpoint
- Diagnostics command prints:
  - published TXT records (especially `features`)
  - ports bound
  - audio output device chosen
  - pairing DB status

---

## 17) Known risks & mitigations

### Risk: AirPlay 2 behavior changes in new iOS versions
- Mitigation: keep upstream RE receiver close; add compatibility test matrix; packet captures for regressions.

### Risk: MFi requirements for production distribution
- Mitigation: treat as internal/prototype unless you engage Apple MFi and implement compliant authentication paths.

### Risk: Sync quality is “good enough” but not excellent
- Mitigation: implement drift correction early; add metrics to quantify drift and buffer health.

### Risk: Windows multicast / firewall issues
- Mitigation: installer adds firewall rules; provide diagnostic tool for mDNS send/receive.

---

## 18) Engineering backlog (concrete tasks)

### 18.1 MVP backlog
- [ ] Fork upstream receiver
- [ ] Add config model and defaults
- [ ] Force multi-room minimal `features` advertisement by default
- [ ] WASAPI output selection + stable device handling
- [ ] PyInstaller build pipeline for single EXE
- [ ] Windows service install/uninstall commands
- [ ] Diagnostics CLI

### 18.2 Sync backlog
- [ ] Implement/enable PTP module (software timestamp MVP)
- [ ] Implement drift correction
- [ ] Add sync health metrics

---

## 19) References (public / reverse-engineered resources)

> These are the primary public resources used for this spike. AirPlay 2 is proprietary; these links reflect reverse engineering and open-source implementations.

- AirPlay 2 Internals (Emanuele Cozzi): https://emanuelecozzi.net/docs/airplay2  
  - Service discovery: https://emanuelecozzi.net/docs/airplay2/discovery/  
  - Features bitmask + **minimal multi-room set**: https://emanuelecozzi.net/docs/airplay2/features/  
  - Authentication precedence + notes: https://emanuelecozzi.net/docs/airplay2/authentication/  
  - Encryption notes: https://emanuelecozzi.net/docs/airplay2/encryption/  
  - RTP encryption details: https://emanuelecozzi.net/docs/airplay2/rtp/  

- openairplay/airplay2-receiver (Python): https://github.com/openairplay/airplay2-receiver  

- Unofficial AirPlay Protocol Specification (legacy but useful):  
  - https://openairplay.github.io/airplay-spec/  
  - https://nto.github.io/AirPlay.html  

- UxPlay Wiki: AirPlay 2 protocol info collection:  
  - https://github.com/FDH2/UxPlay/wiki/AirPlay2-protocol  

- Shairport Sync (AirPlay / AirPlay 2 audio player): https://github.com/mikebrady/shairport-sync  

- goplay2 (Go AirPlay 2 speaker): https://github.com/openairplay/goplay2  

- SteeBono/airplayreceiver (.NET): https://github.com/SteeBono/airplayreceiver  
