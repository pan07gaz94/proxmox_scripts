#!/bin/bash

#############################################################################
# Rustdesk Server Installation - Alpine Linux
# Auto-detects and downloads the LATEST available version
# Supports: x64 (64-bit)
#############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Functions
print_header() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}================================================${NC}"
}

print_step() {
    echo -e "${BLUE}[$1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}✓${NC} $2"
}

print_error() {
    echo -e "${RED}✗${NC} $2"
    exit 1
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $2"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $2"
}

#############################################################################
# STEP 0: DETECT LATEST VERSION
#############################################################################

print_header "  Rustdesk Server - Alpine Linux Setup"
echo ""
print_step "0/7" "Detecting latest Rustdesk version..."

# Get latest release from GitHub API
LATEST_RELEASE=$(curl -s https://api.github.com/repos/rustdesk/rustdesk-server/releases | \
    grep '"tag_name"' | \
    grep -v 'pre' | \
    grep -v 'beta' | \
    grep -v 'alpha' | \
    head -1 | \
    cut -d'"' -f4)

if [ -z "$LATEST_RELEASE" ]; then
    print_warning "Could not auto-detect version, trying fallback..."
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/rustdesk/rustdesk-server/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
fi

if [ -z "$LATEST_RELEASE" ]; then
    print_warning "Could not detect from GitHub API"
    LATEST_RELEASE="1.1.9"
    print_info "Using fallback version: $LATEST_RELEASE"
else
    print_success "0/7" "Latest version detected: $LATEST_RELEASE"
fi

echo ""

#############################################################################
# STEP 1: SSH SERVER SETUP
#############################################################################

print_step "1/7" "Installing SSH server..."

if rc-status 2>/dev/null | grep -q "sshd"; then
    print_success "1/7" "SSH server already running"
else
    print_info "Installing OpenSSH..."
    apk add openssh >/dev/null 2>&1 || true
    rc-update add sshd >/dev/null 2>&1 || true
    rc-service sshd start >/dev/null 2>&1 || true
    print_success "1/7" "SSH server installed and started"
fi

SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
print_info "SSH listening on port: $SSH_PORT"

echo ""

#############################################################################
# STEP 2: UPDATE SYSTEM
#############################################################################

print_step "2/7" "Updating Alpine packages..."

apk update >/dev/null 2>&1 || true
apk add --no-cache wget curl unzip ca-certificates net-tools >/dev/null 2>&1

print_success "2/7" "Alpine packages updated"
echo ""

#############################################################################
# STEP 3: CREATE DIRECTORIES
#############################################################################

print_step "3/7" "Creating directories..."

INSTALL_DIR="/opt/rustdesk-server"
CONFIG_DIR="/etc/rustdesk"
LOG_DIR="/var/log/rustdesk"

mkdir -p $INSTALL_DIR $CONFIG_DIR $LOG_DIR
chmod 755 $INSTALL_DIR $CONFIG_DIR $LOG_DIR

print_success "3/7" "Directories created"
print_info "  Install: $INSTALL_DIR"
print_info "  Config:  $CONFIG_DIR"
print_info "  Logs:    $LOG_DIR"

echo ""

#############################################################################
# STEP 4: DOWNLOAD AND EXTRACT BINARIES
#############################################################################

print_step "4/7" "Downloading Rustdesk Server v$LATEST_RELEASE..."

cd /tmp

# Clean up old files
rm -f rustdesk*.zip hbbs hbbr 2>/dev/null || true

DOWNLOAD_URL="https://github.com/rustdesk/rustdesk-server/releases/download/$LATEST_RELEASE/rustdesk-server-linux-x64.zip"

print_info "Download URL: $DOWNLOAD_URL"

# Download with retries
MAX_RETRIES=3
RETRY=0
DOWNLOAD_SUCCESS=0

while [ $RETRY -lt $MAX_RETRIES ]; do
    print_info "Attempting download (attempt $((RETRY + 1))/$MAX_RETRIES)..."
    
    if wget --progress=dot:giga -q "$DOWNLOAD_URL" -O rustdesk-server.zip 2>/dev/null; then
        print_success "4/7" "Download successful"
        DOWNLOAD_SUCCESS=1
        break
    else
        RETRY=$((RETRY + 1))
        if [ $RETRY -lt $MAX_RETRIES ]; then
            print_warning "Download attempt $RETRY failed, retrying..."
            sleep 2
        fi
    fi
done

if [ $DOWNLOAD_SUCCESS -eq 0 ]; then
    print_error "4/7" "Failed to download Rustdesk after $MAX_RETRIES attempts"
fi

# Extract
print_info "Extracting files..."

if unzip -q rustdesk-server.zip 2>/dev/null; then
    print_success "4/7" "Extraction successful"
else
    print_warning "Silent extraction failed, trying with output..."
    unzip rustdesk-server.zip > /dev/null 2>&1 || {
        print_error "4/7" "Failed to extract Rustdesk files"
    }
fi

# Verify binaries
if [ ! -f hbbs ] || [ ! -f hbbr ]; then
    print_error "4/7" "Binaries not found after extraction. Available files:"
    ls -la | grep -E "hb|rustdesk"
    exit 1
fi

# Install binaries
cp hbbs hbbr $INSTALL_DIR/
chmod +x $INSTALL_DIR/hbbs $INSTALL_DIR/hbbr

# Cleanup
rm -f rustdesk-server.zip hbbs hbbr

echo ""

#############################################################################
# STEP 5: CREATE OPENRC SERVICES
#############################################################################

print_step "5/7" "Creating OpenRC services..."

# HBBS Service
cat > /etc/init.d/rustdesk-hbbs << 'SVCFILE'
#!/sbin/openrc-run

description="Rustdesk Signal Server (HBBS)"
command="/opt/rustdesk-server/hbbs"
command_args="-h 0.0.0.0"
pidfile="/var/run/rustdesk-hbbs.pid"
command_background="yes"
output_log="/var/log/rustdesk/hbbs.log"
error_log="/var/log/rustdesk/hbbs.log"

depend() {
    need net
}

start_pre() {
    mkdir -p /var/log/rustdesk
}
SVCFILE

# HBBR Service
cat > /etc/init.d/rustdesk-hbbr << 'SVCFILE'
#!/sbin/openrc-run

description="Rustdesk Relay Server (HBBR)"
command="/opt/rustdesk-server/hbbr"
command_args="-h 0.0.0.0"
pidfile="/var/run/rustdesk-hbbr.pid"
command_background="yes"
output_log="/var/log/rustdesk/hbbr.log"
error_log="/var/log/rustdesk/hbbr.log"

depend() {
    need net
    use rustdesk-hbbs
}

start_pre() {
    mkdir -p /var/log/rustdesk
}
SVCFILE

chmod +x /etc/init.d/rustdesk-hbbs /etc/init.d/rustdesk-hbbr

print_success "5/7" "OpenRC services created"
echo ""

#############################################################################
# STEP 6: ENABLE AND START SERVICES
#############################################################################

print_step "6/7" "Starting services..."

rc-update add rustdesk-hbbs 2>/dev/null || true
rc-update add rustdesk-hbbr 2>/dev/null || true

print_info "Starting HBBS (Signal Server)..."
rc-service rustdesk-hbbs start 2>/dev/null || rc-service rustdesk-hbbs start
sleep 2

print_info "Starting HBBR (Relay Server)..."
rc-service rustdesk-hbbr start 2>/dev/null || rc-service rustdesk-hbbr start
sleep 2

print_success "6/7" "Services started and enabled for auto-start"
echo ""

#############################################################################
# STEP 7: VERIFICATION AND DISPLAY INFORMATION
#############################################################################

print_step "7/7" "Verifying installation..."

# Get server information
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || ip addr show | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}' | cut -d/ -f1 || echo "unknown")
HOSTNAME=$(hostname)

# Check if services are running
HBBS_RUNNING=0
HBBR_RUNNING=0

sleep 1

if pgrep -x hbbs >/dev/null 2>&1; then
    HBBS_RUNNING=1
    print_success "7/7" "HBBS process is running"
else
    print_warning "HBBS process verification unclear (may still be starting)"
fi

if pgrep -x hbbr >/dev/null 2>&1; then
    HBBR_RUNNING=1
    print_success "7/7" "HBBR process is running"
else
    print_warning "HBBR process verification unclear (may still be starting)"
fi

echo ""

#############################################################################
# DISPLAY FINAL INFORMATION
#############################################################################

print_header "  ✅ INSTALLATION COMPLETE"

echo ""
echo -e "${CYAN}📍 SERVER INFORMATION:${NC}"
echo "   Hostname:         $HOSTNAME"
echo "   Local IP:         $SERVER_IP"
echo "   SSH Port:         $SSH_PORT"
echo ""
echo -e "${CYAN}🔌 RUSTDESK SERVICES:${NC}"
echo "   Version:          $LATEST_RELEASE"
echo "   HBBS Port:        21115 (Signal Server)"
echo "   HBBR Port:        21116 (Relay Server)"
echo ""
echo -e "${CYAN}📁 INSTALLATION PATHS:${NC}"
echo "   Binaries:         $INSTALL_DIR"
echo "   Config:           $CONFIG_DIR"
echo "   Logs:             $LOG_DIR"
echo ""
echo -e "${CYAN}🔧 USEFUL COMMANDS:${NC}"
echo "   Status:           rc-service rustdesk-hbbs status"
echo "   View logs:        tail -f /var/log/messages"
echo "   Restart:          rc-service rustdesk-hbbs restart && rc-service rustdesk-hbbr restart"
echo "   Stop:             rc-service rustdesk-hbbs stop && rc-service rustdesk-hbbr stop"
echo "   Start:            rc-service rustdesk-hbbs start && rc-service rustdesk-hbbr start"
echo ""

echo -e "${CYAN}================================================${NC}"
echo -e "${GREEN}  🎯 CONFIGURE YOUR CLIENTS WITH:${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""
echo -e "     ${YELLOW}Server Address: ${GREEN}$SERVER_IP:21115${NC}"
echo ""
echo -e "${CYAN}================================================${NC}"
echo ""

echo -e "${CYAN}📋 CLIENT SETUP INSTRUCTIONS:${NC}"
echo ""
echo "  1. Download Rustdesk from: https://rustdesk.com"
echo ""
echo "  2. Install on your client machine"
echo ""
echo "  3. Open Rustdesk → Menu (≡) → Settings → Network"
echo ""
echo "  4. Under 'ID/Relay Server', enter:"
echo -e "     ${YELLOW}$SERVER_IP:21115${NC}"
echo ""
echo "  5. Click 'OK' and restart Rustdesk"
echo ""
echo "  6. Your client will get a unique ID - use that to connect!"
echo ""
echo "  7. (Optional) Add password for security:"
echo "     Menu → Settings → Security → Set password"
echo ""

echo -e "${GREEN}✅ Installation finished!${NC}"
echo -e "${GREEN}✅ Services will start automatically on server reboot${NC}"
echo ""
echo -e "${YELLOW}Note: It may take 10-30 seconds for the services to fully initialize.${NC}"
echo ""
