<h1 align="center" > ⌖ 𝔑𝔢𝔱𝔖𝔠𝔬𝔭𝔢 ⌖ </h1>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-blue" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/Shell-Bash-orange" alt="Shell">
  <img src="https://img.shields.io/badge/Version-1.0-red" alt="Version">
</p>

### ✨ Features :
- Multi-phase scanning: Combines nmap, ARP table analysis, and extended port scanning.
- Smart device detection: Automatically identifies device types based on MAC addresses.
- Public IP geolocation: Displays your external IP with ISP and location info.
- MAC randomization detection: Identifies devices using privacy features.
- Manufacturer identification: Uses local OUI database and online APIs.
- Multi-distro support: Works on Ubuntu, CentOS, Fedora, Arch, Alpine, macOS

### 🎯 Device Types Detected
NetScope can intelligently identify various device categories:
- **Mobile Devices** (with randomized MAC detection)
- **Smart Home Devices** (Google Nest, Amazon Echo, etc.)
- **Network Equipment** (Routers, Switches, Access Points)
- **Gaming Consoles** (Nintendo, PlayStation, Xbox)
- **Computers & Laptops** (Windows, Mac, Linux)
- **Printers & IoT Devices**
- **Raspberry Pi & Development Boards**

## 🚀 Usage
### Basic Usage
```bash
# Scan default range (1-254)
sudo ./netscope.sh

# Scan specific IP range (1-100)
sudo ./netscope.sh 100

# Scan minimal range (1-50) for faster results
sudo ./netscope.sh 50
```

### Command Line Options

```bash
sudo ./netscope.sh [RANGE]
```

- `RANGE`: IP range to scan (1-254, default: 254)

## 📊 Sample Output

```
🌐 Advanced Network Scanner
─────────────────────────────────────────────────────────────────────────

🔍 NETWORK INFORMATION:
├─ Local Network: 192.168.1.1-254
├─ Local IP: 192.168.1.100
├─ Gateway IP: 192.168.1.1
├─ Interface: wlan0
└─ Public IP: 203.0.113.45
   ISP: Example Internet Provider
   Location: New York, NY, US

⚡ Starting network scan...

Scanning: [==================================================] 100%

=== NETWORK SCAN RESULTS ===
IP ADDRESS       MAC ADDRESS        DEVICE TYPE                  RANDOMIZED           MANUFACTURER
==========================================================================================================
192.168.1.1      AA:BB:CC:DD:EE:FF  TP-Link Router              No                   TP-Link Technologies
192.168.1.45     12:34:56:78:9A:BC  Apple Device                No                   Apple Inc.
192.168.1.67     DA:A1:19:00:00:01  Apple Device (Private)      Yes                  Apple Inc.
192.168.1.89     02:00:5E:10:00:00  Mobile Device (Randomized)  Yes                  Unknown
192.168.1.100    FF:EE:DD:CC:BB:AA  Intel Network Adapter       No                   Intel Corporation
192.168.1.156    AB:CD:EF:12:34:56  Samsung Device              No                   Samsung Electronics
==========================================================================================================

📊 SUMMARY:
├─ Total devices found: 6
├─ Devices with randomized MAC: 2
└─ Devices with real MAC: 4
```
