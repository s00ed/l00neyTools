#!/bin/bash

# --- Advanced Network Scanner with DNS, MAC Randomization Detection and Port Scanning ---

shopt -s nocasematch

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo."
  exit 1
fi

# Function to detect package manager and install dependencies
install_dependencies() {
    local missing_deps=()
    
    # Check which commands are missing
    for cmd in nmap curl dig masscan; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check for rustscan separately (it might not be in standard repos)
    if ! command -v rustscan &> /dev/null; then
        missing_deps+=("rustscan")
    fi
    
    # If all dependencies are present, return
    if [ ${#missing_deps[@]} -eq 0 ]; then
        return 0
    fi
    
    echo "⚠️  Missing dependencies: ${missing_deps[*]}"
    echo "🔧 Attempting to install missing dependencies..."
    
    # Detect package manager and install
    if command -v apt-get &> /dev/null; then
        echo "📦 Using apt-get (Debian/Ubuntu)..."
        apt-get update -qq > /dev/null 2>&1
        for dep in "${missing_deps[@]}"; do
            echo "Installing $dep..."
            if [ "$dep" = "dig" ]; then
                apt-get install -y dnsutils > /dev/null 2>&1
            elif [ "$dep" = "masscan" ]; then
                apt-get install -y masscan > /dev/null 2>&1
            elif [ "$dep" = "rustscan" ]; then
                # Try to install rustscan from snap or download binary
                if command -v snap &> /dev/null; then
                    snap install rustscan > /dev/null 2>&1
                else
                    echo "⚠️  RustScan not available via apt. Trying alternative installation..."
                    # Download rustscan binary for Linux
                    wget -q https://github.com/RustScan/RustScan/releases/download/2.0.1/rustscan_2.0.1_amd64.deb -O /tmp/rustscan.deb > /dev/null 2>&1
                    if [ -f /tmp/rustscan.deb ]; then
                        dpkg -i /tmp/rustscan.deb > /dev/null 2>&1
                        rm -f /tmp/rustscan.deb
                    fi
                fi
            else
                apt-get install -y "$dep" > /dev/null 2>&1
            fi
        done
    elif command -v yum &> /dev/null; then
        echo "📦 Using yum (RHEL/CentOS)..."
        for dep in "${missing_deps[@]}"; do
            echo "Installing $dep..."
            if [ "$dep" = "dig" ]; then
                yum install -y bind-utils > /dev/null 2>&1
            elif [ "$dep" = "masscan" ]; then
                # Masscan might need EPEL
                yum install -y epel-release > /dev/null 2>&1
                yum install -y masscan > /dev/null 2>&1
            elif [ "$dep" = "rustscan" ]; then
                echo "⚠️  RustScan not available via yum. Manual installation required."
            else
                yum install -y "$dep" > /dev/null 2>&1
            fi
        done
    elif command -v dnf &> /dev/null; then
        echo "📦 Using dnf (Fedora)..."
        for dep in "${missing_deps[@]}"; do
            echo "Installing $dep..."
            if [ "$dep" = "dig" ]; then
                dnf install -y bind-utils > /dev/null 2>&1
            elif [ "$dep" = "masscan" ]; then
                dnf install -y masscan > /dev/null 2>&1
            elif [ "$dep" = "rustscan" ]; then
                echo "⚠️  RustScan not available via dnf. Manual installation required."
            else
                dnf install -y "$dep" > /dev/null 2>&1
            fi
        done
    elif command -v pacman &> /dev/null; then
        echo "📦 Using pacman (Arch Linux)..."
        pacman -Sy --noconfirm > /dev/null 2>&1
        for dep in "${missing_deps[@]}"; do
            echo "Installing $dep..."
            if [ "$dep" = "dig" ]; then
                pacman -S --noconfirm bind-tools > /dev/null 2>&1
            elif [ "$dep" = "masscan" ]; then
                pacman -S --noconfirm masscan > /dev/null 2>&1
            elif [ "$dep" = "rustscan" ]; then
                # Try AUR if available
                if command -v yay &> /dev/null; then
                    yay -S --noconfirm rustscan > /dev/null 2>&1
                else
                    echo "⚠️  RustScan not available. Install from AUR manually."
                fi
            else
                pacman -S --noconfirm "$dep" > /dev/null 2>&1
            fi
        done
    elif command -v brew &> /dev/null; then
        echo "📦 Using brew (macOS)..."
        for dep in "${missing_deps[@]}"; do
            echo "Installing $dep..."
            if [ "$dep" = "dig" ]; then
                brew install bind > /dev/null 2>&1
            elif [ "$dep" = "masscan" ]; then
                brew install masscan > /dev/null 2>&1
            elif [ "$dep" = "rustscan" ]; then
                brew install rustscan > /dev/null 2>&1
            else
                brew install "$dep" > /dev/null 2>&1
            fi
        done
    else
        echo "❌ Error: No supported package manager found."
        echo "Please manually install the following dependencies:"
        for dep in "${missing_deps[@]}"; do
            if [ "$dep" = "dig" ]; then
                echo "  - dig (usually in bind-utils, dnsutils, or bind-tools package)"
            else
                echo "  - $dep"
            fi
        done
        exit 1
    fi
    
    # Verify installation
    echo "🔍 Verifying installations..."
    local failed_installs=()
    for cmd in nmap curl dig masscan; do
        if ! command -v "$cmd" &> /dev/null; then
            failed_installs+=("$cmd")
        else
            echo "✓ $cmd installed successfully"
        fi
    done
    
    # RustScan is optional, just warn if not available
    if ! command -v rustscan &> /dev/null; then
        echo "⚠️  RustScan not available - will use nmap for all port scans"
    else
        echo "✓ rustscan installed successfully"
    fi
    
    if [ ${#failed_installs[@]} -gt 0 ]; then
        echo "❌ Failed to install: ${failed_installs[*]}"
        echo "Please install these dependencies manually and try again."
        exit 1
    fi
    
    echo "✅ Core dependencies installed successfully!"
    echo ""
}

# --- Global Arrays to Store Unique Devices ---
declare -A DEVICES
declare -A DEVICE_INFO

# --- Functions ---

validate_input() {
  if ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ] || [ "$1" -gt 254 ]; then
    echo "Error: Invalid range. Please provide a number between 1 and 254."
    exit 1
  fi
}

# Get ACTUAL DNS servers being used (like dnsleaktest.com approach)
get_real_dns_servers() {


    local targets=(
      "TXT whoami.cloudflare"
      "A   whoami.akamai.net"
      "AAAA whoami.akamai.net"
      "A   whoami.ultradns.net"
    )

    local ips=()
    query() {
      local rr="$1" name="$2"
      dig +time=2 +tries=1 +short "$name" "$rr" 2>/dev/null | sed 's/"//g'
    }

    for _ in 1 2 3; do
      for entry in "${targets[@]}"; do
        read -r type name <<<"$entry"
        out="$(query "$type" "$name" || true)"
        [ -n "$out" ] || continue
        while IFS= read -r line; do
          if [[ "$line" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ || "$line" =~ : ]]; then
            ips+=("$line")
          fi
        done <<<"$out"
      done
    done

    mapfile -t unique < <(printf "%s
" "${ips[@]:-}" \
      | grep -E -v '^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|0\.|169\.254\.)' \
      | sort -u)

    if ((${#unique[@]}==0)); then
      echo "No public upstream resolver IPs discovered." >&2
      return 1
    fi

    printf "%s
" "${unique[@]}"
}

# Get public IP address
get_public_ip() {
    local public_ip=""
    
    # Method 1: Try OpenDNS first (most reliable)
    if command -v dig &> /dev/null; then
        public_ip=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null | tr -d '[:space:]')
        
        # Validate IP format
        if [[ $public_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$public_ip"
            return 0
        fi
    fi
    
    # Method 2: Fallback to HTTP services
    local services=(
        "https://ipinfo.io/ip"
        "https://icanhazip.com"
        "https://api.ipify.org"
        "https://checkip.amazonaws.com"
        "https://ip.seeip.org"
    )
    
    for service in "${services[@]}"; do
        public_ip=$(curl -s --connect-timeout 3 --max-time 5 "$service" 2>/dev/null | tr -d '[:space:]')
        
        # Validate IP format
        if [[ $public_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "$public_ip"
            return 0
        fi
    done
    
    echo "Unable to detect"
    return 1
}

# Get ISP/Location info for public IP
get_public_ip_info() {
    local public_ip=$1
    local info=""
    
    if [[ "$public_ip" != "Unable to detect" ]]; then
        info=$(curl -s --connect-timeout 5 --max-time 10 "https://ipinfo.io/$public_ip/json" 2>/dev/null)
        
        if [[ -n "$info" && "$info" != *"error"* ]]; then
            local isp=$(echo "$info" | grep -o '"org":"[^"]*' | cut -d'"' -f4)
            local city=$(echo "$info" | grep -o '"city":"[^"]*' | cut -d'"' -f4)
            local region=$(echo "$info" | grep -o '"region":"[^"]*' | cut -d'"' -f4)
            local country=$(echo "$info" | grep -o '"country":"[^"]*' | cut -d'"' -f4)
            
            if [[ -n "$isp" ]]; then
                echo "ISP: $isp"
            fi
            if [[ -n "$city" && -n "$region" && -n "$country" ]]; then
                echo "Location: $city, $region, $country"
            fi
        fi
    fi
}

# Check if MAC address is randomized
is_randomized_mac() {
    local mac=$1
    local oui="${mac:0:8}"
    
    # Convert first octet to decimal to check the locally administered bit
    local first_octet="${mac:0:2}"
    local decimal_value=$((16#$first_octet))
    
    # Check if bit 1 (locally administered bit) is set
    if (( (decimal_value & 2) == 2 )); then
        return 0  # True - locally administered (potentially randomized)
    fi
    
    # Check for common randomized MAC patterns
    case "$oui" in
        "02:00:00"|"06:00:00"|"0A:00:00"|"0E:00:00"|"12:00:00"|"16:00:00")
            return 0  # Common randomized prefixes
            ;;
        "02:"*|"06:"*|"0A:"*|"0E:"*|"12:"*|"16:"*|"1A:"*|"1E:"*)
            return 0  # Locally administered ranges
            ;;
    esac
    
    return 1  # False - likely not randomized
}

# Get manufacturer from OUI database (local lookup)
get_manufacturer_oui() {
    local mac=$1
    local oui="${mac:0:8}"
    
    # Remove colons and convert to uppercase for OUI lookup
    local oui_clean=$(echo "$oui" | tr -d ':' | tr '[:lower:]' '[:upper:]')
    
    # Try local OUI database first (if available)
    if [ -f "/usr/share/nmap/nmap-mac-prefixes" ]; then
        local result=$(grep "^$oui_clean" /usr/share/nmap/nmap-mac-prefixes 2>/dev/null | head -1 | cut -d' ' -f2-)
        if [ -n "$result" ]; then
            echo "$result"
            return
        fi
    fi
    
    # Fallback to online API
    local manufacturer=$(curl -s --connect-timeout 3 "https://api.macvendors.com/${mac}" 2>/dev/null)
    
    if [[ -z "$manufacturer" || "$manufacturer" == *"errors"* || "$manufacturer" == *"Not Found"* ]]; then
        echo "Unknown"
    else
        echo "$manufacturer"
    fi
}

# Advanced device type detection
get_device_type_advanced() {
    local manufacturer_string=$1
    local mac=$2
    local ip=$3
    local device_type="Unknown"
    
    # Check if MAC is randomized first
    if is_randomized_mac "$mac"; then
        device_type="Maybe Mobile Device"
        
        # Try to determine device type from randomized MAC patterns
        local first_octet="${mac:0:2}"
        case "$first_octet" in
            "02"|"06"|"0A"|"0E")
                device_type=" Maybe Mobile Device"
                ;;
            "DA"|"DE")
                device_type="Apple Device (Private Address)"
                ;;
        esac
        
        echo "$device_type"
        return
    fi
    
    # Convert to lowercase for matching
    local lower_manufacturer=$(echo "$manufacturer_string" | tr '[:upper:]' '[:lower:]')
    
    # Detailed device type detection based on manufacturer
    if [[ "$lower_manufacturer" == *"apple"* ]]; then
        device_type="Apple Device"
    elif [[ "$lower_manufacturer" == *"samsung"* ]]; then
        device_type="Samsung Device"
    elif [[ "$lower_manufacturer" == *"google"* || "$lower_manufacturer" == *"nest"* ]]; then
        device_type="Google/Nest Device"
    elif [[ "$lower_manufacturer" == *"amazon"* ]]; then
        device_type="Amazon Echo/Fire Device"
    elif [[ "$lower_manufacturer" == *"raspberry"* ]]; then
        device_type="Raspberry Pi"
    elif [[ "$lower_manufacturer" == *"intel"* ]]; then
        device_type="Intel Network Adapter"
    elif [[ "$lower_manufacturer" == *"realtek"* ]]; then
        device_type="Realtek Network Adapter"
    elif [[ "$lower_manufacturer" == *"broadcom"* ]]; then
        device_type="Broadcom Network Device"
    elif [[ "$lower_manufacturer" == *"qualcomm"* ]]; then
        device_type="Mobile Device (Qualcomm)"
    elif [[ "$lower_manufacturer" == *"mediatek"* ]]; then
        device_type="Router/Mobile (MediaTek)"
    elif [[ "$lower_manufacturer" == *"huawei"* ]]; then
        device_type="Huawei Router/Phone"
    elif [[ "$lower_manufacturer" == *"tp-link"* || "$lower_manufacturer" == *"tplink"* ]]; then
        device_type="TP-Link Router"
    elif [[ "$lower_manufacturer" == *"cisco"* ]]; then
        device_type="Cisco Network Device"
    elif [[ "$lower_manufacturer" == *"netgear"* ]]; then
        device_type="Netgear Router"
    elif [[ "$lower_manufacturer" == *"asus"* ]]; then
        device_type="ASUS Router/Device"
    elif [[ "$lower_manufacturer" == *"linksys"* ]]; then
        device_type="Linksys Router"
    elif [[ "$lower_manufacturer" == *"d-link"* ]]; then
        device_type="D-Link Router"
    elif [[ "$lower_manufacturer" == *"xiaomi"* ]]; then
        device_type="Xiaomi Device"
    elif [[ "$lower_manufacturer" == *"sony"* ]]; then
        device_type="Sony Device"
    elif [[ "$lower_manufacturer" == *"nintendo"* ]]; then
        device_type="Nintendo Console"
    elif [[ "$lower_manufacturer" == *"microsoft"* ]]; then
        device_type="Microsoft Device"
    elif [[ "$lower_manufacturer" == *"dell"* ]]; then
        device_type="Dell Computer"
    elif [[ "$lower_manufacturer" == *"hp"* || "$lower_manufacturer" == *"hewlett"* ]]; then
        device_type="HP Device/Printer"
    elif [[ "$lower_manufacturer" == *"canon"* ]]; then
        device_type="Canon Printer"
    elif [[ "$lower_manufacturer" == *"epson"* ]]; then
        device_type="Epson Printer"
    elif [[ "$lower_manufacturer" == *"fujitsu"* || "$lower_manufacturer" == *"fugui"* ]]; then
        device_type="PC Network Adapter"
    elif [[ "$lower_manufacturer" == *"marvell"* ]]; then
        device_type="Network Controller"
    elif [[ "$lower_manufacturer" == *"atheros"* ]]; then
        device_type="Wireless Adapter"
    elif [[ "$lower_manufacturer" == *"router"* || "$lower_manufacturer" == *"gateway"* ]]; then
        device_type="Router/Gateway"
    fi
    
    echo "$device_type"
}

# Add device to our tracking arrays (fixed duplicate handling)
add_device() {
    local ip=$1
    local mac=$2
    local label=$3
    
    # Normalize MAC address to uppercase for consistent comparison
    mac=$(echo "$mac" | tr '[:lower:]' '[:upper:]')
    
    # Use MAC as key to avoid duplicates
    if [[ -z "${DEVICES[$mac]}" ]]; then
        DEVICES[$mac]="$ip"
        DEVICE_INFO[$mac]="$label"
    fi
}

# Display network information header
display_network_info() {
    echo "🔍 NETWORK INFORMATION:"
    echo "├─ Local Network: $SCAN_TARGET"
    echo "├─ Local IP: $LOCAL_IP"
    echo "├─ Gateway IP: $GATEWAY_IP"
    echo "├─ Interface: $IFACE"
    echo "├─ DNS: $DNS_SERVERS"
    echo "└─ Public IP: $PUBLIC_IP"
    
    if [[ "$PUBLIC_IP" != "Unable to detect" ]]; then
        # Get additional public IP info
        local isp_info=$(get_public_ip_info "$PUBLIC_IP")
        if [[ -n "$isp_info" ]]; then
            echo "   $isp_info" | sed 's/^/   /'
        fi
    fi
    
    echo ""
}

# Display all unique devices
display_devices() {
    echo ""
    echo "=== NETWORK SCAN RESULTS ==="
    printf "%-16s %-18s %-28s %-20s %s\n" "IP ADDRESS" "MAC ADDRESS" "DEVICE TYPE" "RANDOMIZED/PRIVATE" "MANUFACTURER"
    echo "=========================================================================================================="
    
    # Sort devices by IP address
    for mac in "${!DEVICES[@]}"; do
        local ip="${DEVICES[$mac]}"
        local label="${DEVICE_INFO[$mac]}"
        
        echo "$ip|$mac|$label"
    done | sort -t'|' -k1,1V | while IFS='|' read -r ip mac label; do
        local manufacturer=$(get_manufacturer_oui "$mac")
        local device_type=$(get_device_type_advanced "$manufacturer" "$mac" "$ip")
        local randomized_status="No"
        
        if is_randomized_mac "$mac"; then
            randomized_status="Yes"
        fi
        
        # Format output
        printf "%-16s %-18s %-28s %-20s %s\n" \
            "$ip" \
            "${mac^^}" \
            "$device_type" \
            "$randomized_status" \
            "$manufacturer"
    done
    
    echo "=========================================================================================================="
    echo ""
    
    # Statistics
    local total_devices=${#DEVICES[@]}
    local randomized_count=0
    
    for mac in "${!DEVICES[@]}"; do
        if is_randomized_mac "$mac"; then
            ((randomized_count++))
        fi
    done
    
    echo "📊 SUMMARY:"
    echo "├─ Total devices found: $total_devices"
    echo "├─ Devices with randomized MAC: $randomized_count"
    echo "└─ Devices with real MAC: $((total_devices - randomized_count))"
    echo ""
}

# Port scanning function
port_scan() {
    echo ""
    echo "🔍 PORT SCANNING"
    echo "─────────────────────────────────────────────────────────────────────────"
    echo ""
    
    # Get list of active IPs
    local active_ips=()
    for mac in "${!DEVICES[@]}"; do
        active_ips+=("${DEVICES[$mac]}")
    done
    
    if [ ${#active_ips[@]} -eq 0 ]; then
        echo "No active devices found for port scanning."
        return
    fi
    
    local ip_count=${#active_ips[@]}
    echo "📡 Found $ip_count active device(s) for port scanning"
    
    # Choose scanning method based on IP count and available tools
    if [ $ip_count -gt 5 ] && command -v masscan &> /dev/null; then
        echo "🚀 Using Masscan for large range scanning (0-60000 ports)..."
        perform_masscan "${active_ips[@]}"
    elif command -v rustscan &> /dev/null; then
        echo "🦀 Using RustScan for fast port detection..."
        perform_rustscan "${active_ips[@]}"
    else
        echo "🔧 Using Nmap for port scanning..."
        perform_nmap_scan "${active_ips[@]}"
    fi
}

# Port scanning progress bar
show_port_progress() {
    local current=$1
    local total=$2
    local ip=$3
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    
    printf "\r🔍 Scanning $ip: ["
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $((width - filled)) | tr ' ' '-'
    printf "] %d%% (%d/%d)" $percent $current $total
}

# Masscan implementation with progress
perform_masscan() {
    local ips=("$@")
    local target_list=$(IFS=','; echo "${ips[*]}")
    local total_ips=${#ips[@]}
    
    echo "🚀 Scanning ports 1-60000 on $total_ips hosts with Masscan..."
    echo ""
    
    # Run masscan with progress simulation
    show_port_progress 0 100 "all hosts"
    
    local masscan_results=$(masscan -p1-60000 --rate=1000 --wait=3 $target_list 2>/dev/null | grep "open" &)
    local masscan_pid=$!
    
    # Simulate progress while masscan runs
    local progress=0
    while kill -0 $masscan_pid 2>/dev/null; do
        progress=$((progress + 2))
        if [ $progress -gt 95 ]; then progress=95; fi
        show_port_progress $progress 100 "all hosts"
        sleep 1
    done
    
    wait $masscan_pid
    masscan_results=$(masscan -p1-60000 --rate=1000 --wait=3 $target_list 2>/dev/null | grep "open")
    show_port_progress 100 100 "all hosts"
    echo ""
    echo ""
    
    if [[ -n "$masscan_results" ]]; then
        echo "🎯 Open ports found with Masscan:"
        echo "=================================="
        
        # Process results and group by IP
        declare -A ip_ports
        echo "$masscan_results" | while read -r line; do
            if [[ $line =~ Discovered\ open\ port\ ([0-9]+)\/tcp\ on\ ([0-9\.]+) ]]; then
                local port="${BASH_REMATCH[1]}"
                local ip="${BASH_REMATCH[2]}"
                echo "├─ $ip:$port"
            fi
        done
        
        echo ""
        echo "🔍 Running detailed Nmap scan on discovered ports..."
        echo ""
        
        # Extract unique IPs with open ports for detailed scanning
        local detailed_targets=$(echo "$masscan_results" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u)
        local target_count=$(echo "$detailed_targets" | wc -l)
        local current=0
        
        for target_ip in $detailed_targets; do
            current=$((current + 1))
            local open_ports=$(echo "$masscan_results" | grep "$target_ip" | grep -oE 'port [0-9]+' | cut -d' ' -f2 | tr '\n' ',' | sed 's/,$//')
            
            if [[ -n "$open_ports" ]]; then
                show_port_progress $current $target_count "$target_ip"
                local nmap_result=$(nmap -sS -sV -O -p "$open_ports" "$target_ip" 2>/dev/null)
                echo ""
                echo "📡 Detailed scan of $target_ip (ports: $open_ports):"
                echo "$nmap_result" | grep -E "(PORT|tcp|udp|Service|OS|Device)" | grep -v "Not shown"
                echo ""
            fi
        done
    else
        echo "❌ No open ports found in the scanned range."
    fi
}

# RustScan implementation with progress
perform_rustscan() {
    local ips=("$@")
    local total_ips=${#ips[@]}
    local current=0
    
    echo "🦀 Using RustScan for fast port detection..."
    echo ""
    
    for ip in "${ips[@]}"; do
        current=$((current + 1))
        show_port_progress $current $total_ips "$ip"
        
        # Run rustscan with timeout
        local rustscan_results=$(timeout 60 rustscan -a "$ip" -r 1-65535 --timeout 1000 2>/dev/null | grep "Open")
        
        echo ""
        if [[ -n "$rustscan_results" ]]; then
            echo "🎯 Open ports found on $ip:"
            local open_ports=$(echo "$rustscan_results" | grep -oE '[0-9]+' | tr '\n' ',' | sed 's/,$//')
            
            if [[ -n "$open_ports" ]]; then
                echo "🔍 Running detailed Nmap scan..."
                local nmap_result=$(nmap -sS -sV -O -p "$open_ports" "$ip" 2>/dev/null)
                echo "📡 Detailed scan results:"
                echo "$nmap_result" | grep -E "(PORT|tcp|udp|Service|OS|Device)" | grep -v "Not shown"
            fi
        else
            echo "❌ No open ports found on $ip"
        fi
        echo ""
    done
}

# Standard Nmap scan implementation with progress
perform_nmap_scan() {
    local ips=("$@")
    local total_ips=${#ips[@]}
    local current=0
    
    echo "🔧 Using Nmap for comprehensive port scanning..."
    echo ""
    
    for ip in "${ips[@]}"; do
        current=$((current + 1))
        show_port_progress $current $total_ips "$ip"
        
        echo ""
        echo "📡 Scanning common ports on $ip..."
        
        # Quick scan of common ports first
        local quick_results=$(nmap -sS --top-ports 1000 "$ip" 2>/dev/null | grep "open")
        
        if [[ -n "$quick_results" ]]; then
            echo "🎯 Open ports found:"
            echo "$quick_results"
            
            # Get open port numbers for detailed scan
            local open_ports=$(echo "$quick_results" | grep -oE '^[0-9]+' | tr '\n' ',' | sed 's/,$//')
            
            if [[ -n "$open_ports" ]]; then
                echo "🔍 Running detailed service and OS detection..."
                local detailed_results=$(nmap -sS -sV -O -p "$open_ports" "$ip" 2>/dev/null)
                echo "$detailed_results" | grep -E "(Service|OS|Device)"
            fi
        else
            echo "❌ No open ports found (common ports)"
        fi
        echo ""
    done
}

# --- Main Logic ---

# First, install dependencies if needed
install_dependencies

SCAN_RANGE=${1:-254}
validate_input "$SCAN_RANGE"

# Get public IP first
PUBLIC_IP=$(get_public_ip)

# Get network information
IFACE_INFO=$(ip -o -4 addr show | awk '/scope global/ {print $2, $4}' | head -n 1)
IFACE=$(echo "$IFACE_INFO" | awk '{print $1}')
SUBNET=$(echo "$IFACE_INFO" | awk '{print $2}')
LOCAL_IP=$(echo "$SUBNET" | cut -d'/' -f1)
GATEWAY_IP=$(ip route show default | awk '/default/ {print $3}' | head -n 1)

if [ -z "$SUBNET" ]; then
    echo "Error: Could not determine the local network subnet."
    exit 1
fi

NETWORK_PREFIX=$(echo "$LOCAL_IP" | cut -d'.' -f1-3)
SCAN_TARGET="$NETWORK_PREFIX.1-$SCAN_RANGE"

# Now get DNS servers after we have interface info
DNS_SERVERS=$(get_real_dns_servers)

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    
    printf "\rScanning: ["
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $((width - filled)) | tr ' ' '-'
    printf "] %d%%" $percent
}

# Display network information
display_network_info

# Add local machine
LOCAL_MAC=$(cat "/sys/class/net/$IFACE/address" 2>/dev/null)
if [ -n "$LOCAL_MAC" ]; then
    add_device "$LOCAL_IP" "$LOCAL_MAC" "Local Machine"
fi

# Add gateway
if [ -n "$GATEWAY_IP" ] && [ "$GATEWAY_IP" != "$LOCAL_IP" ]; then
    ping -c 1 -W 2 "$GATEWAY_IP" >/dev/null 2>&1
    GATEWAY_MAC=$(arp -n "$GATEWAY_IP" 2>/dev/null | awk '{print $3}' | grep -E "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}")
    if [ -n "$GATEWAY_MAC" ]; then
        add_device "$GATEWAY_IP" "$GATEWAY_MAC" "Gateway"
    fi
fi

echo "⚡ Starting network scan..."
echo ""

# Phase 1: Standard scan
show_progress 1 4
nmap -sn -PR "$SCAN_TARGET" 2>/dev/null | grep -E 'Nmap scan report for|MAC Address:' | while read -r line; do
    if [[ $line == "Nmap scan report for "* ]]; then
        ip=$(echo "$line" | awk '{print $NF}' | tr -d '()')
    elif [[ $line == "MAC Address: "* ]]; then
        mac=$(echo "$line" | awk '{print $3}')
        if [[ "$ip" != "$LOCAL_IP" ]]; then
            echo "$ip|$mac|Standard Scan" >> /tmp/scan_results.tmp
        fi
    fi
done

# Phase 2: ARP table scan
show_progress 2 4
arp -a | grep -E "^\S+.*\([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\)" | while read -r line; do
    ip=$(echo "$line" | sed -n 's/.*(\([0-9.]*\)).*/\1/p')
    mac=$(echo "$line" | grep -oE "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}")
    
    if [[ -n "$mac" && "$ip" != "$LOCAL_IP" ]]; then
        ip_last_octet=$(echo "$ip" | cut -d'.' -f4)
        if [[ "$ip_last_octet" -le "$SCAN_RANGE" ]]; then
            echo "$ip|$mac|ARP Table" >> /tmp/scan_results.tmp
        fi
    fi
done

# Phase 3: Extended scan
show_progress 3 4
nmap -sn -PS80,443,22 -PA80,443,22 -PU53,67,68 "$SCAN_TARGET" 2>/dev/null | grep -E 'Nmap scan report for|MAC Address:' | while read -r line; do
    if [[ $line == "Nmap scan report for "* ]]; then
        ip=$(echo "$line" | awk '{print $NF}' | tr -d '()')
    elif [[ $line == "MAC Address: "* ]]; then
        mac=$(echo "$line" | awk '{print $3}')
        if [[ "$ip" != "$LOCAL_IP" ]]; then
            echo "$ip|$mac|Extended Scan" >> /tmp/scan_results.tmp
        fi
    fi
done

# Phase 4: Complete
show_progress 4 4
echo ""  # New line after progress bar

# Process all results and remove duplicates
if [ -f "/tmp/scan_results.tmp" ]; then
    # Process each line and let add_device handle duplicates
    while IFS='|' read -r ip mac method; do
        add_device "$ip" "$mac" "$method"
    done < /tmp/scan_results.tmp
    rm -f /tmp/scan_results.tmp
fi

# Display results
display_devices

# Ask user if they want to perform port scanning
echo "🚀 PORT SCANNING OPTIONS"
echo "─────────────────────────────────────────────────────────────────────────"
echo ""
read -p "Do you want to perform port scanning on discovered devices? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    port_scan
else
    echo "Port scanning skipped. Network discovery complete!"
fi

echo ""
echo "✅ Scan complete! All results have been displayed above."
