#!/bin/bash

#############################################################################
# Rustdesk Server Setup for Alpine Linux
# Architecture: x64 (64-bit)
# Compatible with: Alpine 3.16+
#############################################################################

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

#############################################################################
# STEP 1: SSH SERVER SETUP (if needed)
#############################################################################

print_status "=== STEP 1: SSH SERVER SETUP ==="

# Check if SSH is already running
if rc-status | grep -q "sshd"; then
    print_success "SSH server (sshd) is already installed and running"
else
    print_status "Installing SSH server..."
    apk update
    apk add openssh
    
    # Enable SSH to start on boot
    rc-update add sshd
    
    # Start SSH
    rc-service sshd start
    
    print_success "SSH server installed and started"
    print_status "SSH will start automatically on reboot"
fi

# Display SSH port
SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')
SSH_PORT=${SSH_PORT:-22}
print_status "SSH is listening on port: $SSH_PORT"

#############################################################################
# STEP 2: SYSTEM PREPARATION
#############################################################################

print_status ""
print_status "=== STEP 2: SYSTEM PREPARATION ==="

# Update Alpine repositories
print_status "Updating Alpine packages..."
apk update
apk add --no-cache \
    wget \
    curl \
    unzip \
    ca-certificates \
    net-tools

print_success "Alpine packages updated"

#############################################################################
# STEP 3: CREATE RUSTDESK DIRECTORIES
#############################################################################

print_status ""
print_status "=== STEP 3: CREATING DIRECTORIES ==="

INSTALL_DIR="/opt/rustdesk-server"
CONFIG_DIR="/etc/rustdesk"
LOG_DIR="/var/log/rustdesk"

mkdir -p $INSTALL_DIR
mkdir -p $CONFIG_DIR
mkdir -p $LOG_DIR

chmod 755 $INSTALL_DIR
chmod 755 $CONFIG_DIR
chmod 755 $LOG_DIR

print_success "Directories created:"
echo "  Install: $INSTALL_DIR"
echo "  Config: $CONFIG_DIR"
echo "  Logs: $LOG_DIR"

#############################################################################
# STEP 4: DOWNLOAD RUSTDESK BINARIES
#############################################################################

print_status ""
print_status "=== STEP 4: DOWNLOADING RUSTDESK SERVER ==="

cd /tmp

RUSTDESK_VERSION="1.1.11"
DOWNLOAD_URL="https://github.com/rustdesk/rustdesk-server/releases/download/${RUSTDESK_VERSION}/rustdesk-server-linux-x64.zip"

print_status "Downloading from: $DOWNLOAD_URL"
print_status "This may take a few minutes..."

if ! wget --progress=bar:force "$DOWNLOAD_URL" -O rustdesk-server.zip 2>&1; then
    print_error "Failed to download Rustdesk Server"
    exit 1
fi

print_status "Extracting files..."
unzip -q rustdesk-server.zip

if [ ! -f hbbs ] || [ ! -f hbbr ]; then
    print_error "Failed to extract binaries"
    exit 1
fi

# Copy to installation directory
cp hbbs hbbr $INSTALL_DIR/
chmod +x $INSTALL_DIR/hbbs $INSTALL_DIR/hbbr

# Clean up
rm -f rustdesk-server.zip hbbs hbbr

print_success "Rustdesk binaries installed"

#############################################################################
# STEP 5: FIREWALL CONFIGURATION
#############################################################################

print_status ""
print_status "=== STEP 5: FIREWALL CONFIGURATION ==="

HBBS_PORT=21115
HBBR_PORT=21116

# Check if ufw is installed (unlikely on Alpine, but check anyway)
if command -v ufw &> /dev/null; then
    print_status "Configuring UFW firewall..."
    ufw allow $HBBS_PORT/tcp
    ufw allow $HBBS_PORT/udp
    ufw allow $HBBR_PORT/tcp
    ufw allow $HBBR_PORT/udp
    print_success "UFW rules added"
else
    print_status "Alpine uses iptables/netfilter"
    print_warning "If you have a firewall, ensure these ports are open:"
    echo "  - TCP: $HBBS_PORT (Signal Server)"
    echo "  - UDP: $HBBS_PORT (Signal Server)"
    echo "  - TCP: $HBBR_PORT (Relay Server)"
    echo "  - UDP: $HBBR_PORT (Relay Server)"
fi

#############################################################################
# STEP 6: OPENRC INIT SERVICES (Alpine's init system)
#############################################################################

print_status ""
print_status "=== STEP 6: CREATING OPENRC SERVICES ==="

# Create HBBS service
cat > /etc/init.d/rustdesk-hbbs << 'SVCEOF'
#!/sbin/openrc-run

description="Rustdesk Signal Server (HBBS)"
command="/opt/rustdesk-server/hbbs"
command_args="-h 0.0.0.0"
pidfile="/var/run/rustdesk-hbbs.pid"
command_background="yes"

depend() {
    need net
}

start_pre() {
    mkdir -p /var/log/rustdesk
}

SVCEOF

chmod +x /etc/init.d/rustdesk-hbbs

# Create HBBR service
cat > /etc/init.d/rustdesk-hbbr << 'SVCEOF'
#!/sbin/openrc-run

description="Rustdesk Relay Server (HBBR)"
command="/opt/rustdesk-server/hbbr"
command_args="-h 0.0.0.0"
pidfile="/var/run/rustdesk-hbbr.pid"
command_background="yes"

depend() {
    need net
    use rustdesk-hbbs
}

SVCEOF

chmod +x /etc/init.d/rustdesk-hbbr

print_success "OpenRC services created"

#############################################################################
# STEP 7: ENABLE AND START SERVICES
#############################################################################

print_status ""
print_status "=== STEP 7: STARTING SERVICES ==="

# Add services to default runlevel
rc-update add rustdesk-hbbs
rc-update add rustdesk-hbbr

print_status "Starting HBBS..."
rc-service rustdesk-hbbs start
sleep 2

print_status "Starting HBBR..."
rc-service rustdesk-hbbr start
sleep 2

print_success "Services started"

#############################################################################
# STEP 8: VERIFICATION
#############################################################################

print_status ""
print_status "=== STEP 8: VERIFICATION ==="

# Check if services are running
print_status "Checking service status..."

if rc-service rustdesk-hbbs status 2>&1 | grep -q "started"; then
    print_success "HBBS is running"
else
    print_warning "HBBS status unclear, checking processes..."
    if pgrep hbbs > /dev/null; then
        print_success "HBBS process is running"
    else
        print_error "HBBS process not found"
    fi
fi

if rc-service rustdesk-hbbr status 2>&1 | grep -q "started"; then
    print_success "HBBR is running"
else
    print_warning "HBBR status unclear, checking processes..."
    if pgrep hbbr > /dev/null; then
        print_success "HBBR process is running"
    else
        print_error "HBBR process not found"
    fi
fi

# Check open ports
print_status "Checking open ports..."
netstat -tuln 2>/dev/null | grep -E "21115|21116" || echo "No listening ports found yet"

#############################################################################
# STEP 9: SERVER INFORMATION
#############################################################################

print_status ""
print_status "=== STEP 9: SERVER INFORMATION ==="

SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "unable to retrieve")

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║            RUSTDESK SERVER SETUP COMPLETE (Alpine)             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📍 NETWORK INFORMATION:"
echo "  Local IP:     $SERVER_IP"
echo "  Public IP:    $PUBLIC_IP"
echo ""
echo "🔌 SERVICE INFORMATION:"
echo "  HBBS Port:    21115 (Signal Server)"
echo "  HBBR Port:    21116 (Relay Server)"
echo ""
echo "📁 INSTALLATION PATHS:"
echo "  Binaries:     $INSTALL_DIR"
echo "  Config:       $CONFIG_DIR"
echo "  Logs:         $LOG_DIR"
echo ""
echo "🔧 USEFUL COMMANDS:"
echo "  Check status:    rc-service rustdesk-hbbs status"
echo "  View logs:       tail -f /var/log/messages"
echo "  Start service:   rc-service rustdesk-hbbs start"
echo "  Stop service:    rc-service rustdesk-hbbs stop"
echo "  Restart service: rc-service rustdesk-hbbs restart"
echo ""
echo "📋 CONFIGURE CLIENTS WITH:"
echo "  Server Address: $PUBLIC_IP:21115"
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    SSH SERVER INFORMATION                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "🔐 SSH ACCESS:"
echo "  ssh root@$SERVER_IP"
echo "  SSH Port: $SSH_PORT"
echo ""

#############################################################################
# STEP 10: POST-INSTALLATION
#############################################################################

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                   NEXT STEPS FOR CLIENTS                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "1. On Windows/Linux client machine, install Rustdesk"
echo ""
echo "2. Open Rustdesk and go to: Menu (≡) → Settings → Network"
echo ""
echo "3. Set 'ID/Relay Server' to:"
echo "   $PUBLIC_IP:21115"
echo ""
echo "4. Click 'OK' and restart Rustdesk"
echo ""
echo "5. The client will show a unique ID - use that to connect!"
echo ""

print_success "Alpine Rustdesk setup completed!"
