# inventory-macOS.sh

[![ShellCheck](https://img.shields.io/badge/shellcheck-passing-brightgreen?logo=gnu-bash&logoColor=white)](https://www.shellcheck.net/)
![macOS](https://img.shields.io/badge/macOS-10.15%2B-blue?logo=apple&logoColor=white)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Pre-enrollment inventory script for macOS that produces a **single, well-formatted text report** you can archive before wiping a device.  
Uses only macOS built-ins (no Python, no `jq`) and is safe to run on unmanaged machines.

---

## What it collects

- **Identity:** Computer Name, LocalHostName, HostName, Console User, Serial
- **OS:** Product name, version & build, uptime, last boot time
- **Hardware:** Model identifier, CPU/Chip, RAM (GB)
- **Storage:** Root volume usage, brief APFS summary (first 40 lines)
- **Network:** IPs (en0/en1), DNS servers, Wi-Fi device + SSID/BSSID/RSSI/channel
- **Security:** FileVault status + enabled users, Gatekeeper, SIP, Firewall state
- **Profiles/MDM:** Enrollment status and installed configuration profiles (if any)
- **Battery (laptops):** Cycle count, estimated health %, charging state
- **Updates:** Raw output of `softwareupdate -l`
- **Applications snapshot:** Top-level names in `/Applications` (quick, not exhaustive)

---

## Output

- **Path:**  
  `/Users/Shared/MacInventory_<serial>_<YYYYmmdd-HHMMSS>.txt`
- **Fallback (if Shared not writable):**  
  `~/Desktop/MacInventory_<serial>_<YYYYmmdd-HHMMSS>.txt`

**Example tail:**
---

## Requirements

- macOS 10.15+ (tested on Intel & Apple silicon)
- Run as **admin**; `sudo` recommended for complete results

---

## Usage

```bash
# From the script directory
sudo bash inventory-macOS.sh

Optional flags (future-proofing; not required today):

--out <dir> (planned): override output directory

Tip: Keep the generated TXT with your intake ticket before wiping.

Exit codes
0 — success
1 — unrecoverable environment error (e.g., cannot create output directory)

License
MIT © / CipherStack.dev