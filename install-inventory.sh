#!/bin/bash

################################################################################
#                                                                              #
#  🚀 INVENTORY MANAGEMENT SYSTEM - COMPLETE AUTO INSTALLATION SCRIPT         #
#  Debian 11/12 on Proxmox                                                    #
#                                                                              #
#  This script will install EVERYTHING in one go:                            #
#  - System updates                                                           #
#  - Node.js v18                                                              #
#  - MongoDB                                                                   #
#  - Application dependencies                                                 #
#  - Services (auto-start)                                                    #
#  - Firewall                                                                 #
#                                                                              #
#  Usage: bash INSTALL.sh                                                    #
#                                                                              #
################################################################################

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress counter
STEP=0
TOTAL_STEPS=12

# ═══════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  📦 INVENTORY MANAGEMENT SYSTEM - AUTO INSTALLATION      ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    STEP=$((STEP + 1))
    echo ""
    echo -e "${YELLOW}[${STEP}/${TOTAL_STEPS}]${NC} $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# ═══════════════════════════════════════════════════════════════════════════
# START INSTALLATION
# ═══════════════════════════════════════════════════════════════════════════

print_header

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root or with sudo"
    echo "Usage: sudo bash INSTALL.sh"
    exit 1
fi

print_info "This script will install everything needed for the Inventory Management System"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# STEP 1: System Update
# ═══════════════════════════════════════════════════════════════════════════

print_step "Updating System Packages"
apt-get update -y
apt-get upgrade -y
apt-get install -y curl git wget build-essential

print_success "System updated"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 2: Install Node.js v18
# ═══════════════════════════════════════════════════════════════════════════

print_step "Installing Node.js v18 LTS"

curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)

print_success "Node.js installed: $NODE_VERSION"
print_success "NPM installed: $NPM_VERSION"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 3: Install MongoDB
# ═══════════════════════════════════════════════════════════════════════════

print_step "Installing MongoDB Community Edition"

wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/debian bullseye/mongodb-org/6.0 main" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list

apt-get update
apt-get install -y mongodb-org

systemctl daemon-reload
systemctl enable mongod
systemctl start mongod

sleep 2

if systemctl is-active --quiet mongod; then
    print_success "MongoDB installed and running"
else
    print_error "MongoDB failed to start"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════
# STEP 4: Create Application Directory
# ═══════════════════════════════════════════════════════════════════════════

print_step "Creating Application Directory"

mkdir -p /opt/inventory-app
cd /opt/inventory-app

print_success "Directory created: /opt/inventory-app"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 5: Check for inventory-app files
# ═══════════════════════════════════════════════════════════════════════════

print_step "Checking for Application Files"

# Look for inventory-app in common locations
if [ -d "$HOME/inventory-app" ]; then
    print_info "Found inventory-app in $HOME"
    cp -r $HOME/inventory-app/* /opt/inventory-app/ 2>/dev/null || true
elif [ -d "./inventory-app" ]; then
    print_info "Found inventory-app in current directory"
    cp -r ./inventory-app/* /opt/inventory-app/ 2>/dev/null || true
else
    print_error "inventory-app folder not found!"
    echo ""
    echo "Please ensure you have copied the inventory-app folder to one of:"
    echo "  - $HOME/inventory-app"
    echo "  - ./inventory-app"
    echo "  - /opt/inventory-app (manually)"
    echo ""
    exit 1
fi

# Verify package.json exists
if [ ! -f "/opt/inventory-app/package.json" ]; then
    print_error "package.json not found in /opt/inventory-app"
    exit 1
fi

print_success "Application files found"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 6: Create .env File
# ═══════════════════════════════════════════════════════════════════════════

print_step "Configuring Environment"

cd /opt/inventory-app

# Generate random JWT secret
JWT_SECRET=$(openssl rand -hex 32)

cat > .env << EOF
MONGODB_URI=mongodb://localhost:27017/inventory_db
PORT=5000
JWT_SECRET=$JWT_SECRET
NODE_ENV=production
FRONTEND_URL=http://localhost:3000
EOF

print_success ".env file created"
print_info "JWT_SECRET: ${JWT_SECRET:0:16}...****"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 7: Install Backend Dependencies
# ═══════════════════════════════════════════════════════════════════════════

print_step "Installing Backend Dependencies"

cd /opt/inventory-app

npm install

print_success "Backend dependencies installed"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 8: Install & Build Frontend
# ═══════════════════════════════════════════════════════════════════════════

print_step "Installing Frontend Dependencies"

cd /opt/inventory-app/client

npm install

print_success "Frontend dependencies installed"

print_step "Building Frontend"

npm run build

print_success "Frontend built successfully"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 9: Create Systemd Services
# ═══════════════════════════════════════════════════════════════════════════

print_step "Creating Systemd Services"

# Backend Service
cat > /etc/systemd/system/inventory-backend.service << 'SERVICEOF'
[Unit]
Description=Inventory Management System - Backend
After=network.target mongod.service
Wants=mongod.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/inventory-app
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEOF

# Frontend Service
cat > /etc/systemd/system/inventory-frontend.service << 'SERVICEOF'
[Unit]
Description=Inventory Management System - Frontend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/inventory-app/client
ExecStart=/usr/bin/npm start
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEOF

systemctl daemon-reload
systemctl enable inventory-backend.service
systemctl enable inventory-frontend.service

print_success "Systemd services created"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 10: Configure Firewall
# ═══════════════════════════════════════════════════════════════════════════

print_step "Configuring Firewall (UFW)"

ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp      # SSH
ufw allow 3000/tcp    # Frontend
ufw allow 5000/tcp    # Backend
ufw reload

print_success "Firewall configured"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 11: Start Services
# ═══════════════════════════════════════════════════════════════════════════

print_step "Starting Services"

systemctl start inventory-backend.service
sleep 3

systemctl start inventory-frontend.service
sleep 2

print_success "Backend service started"
print_success "Frontend service started"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 12: Final Verification
# ═══════════════════════════════════════════════════════════════════════════

print_step "Verifying Installation"

# Check backend
if systemctl is-active --quiet inventory-backend.service; then
    print_success "Backend service is running"
else
    print_error "Backend service failed to start - checking logs..."
    journalctl -u inventory-backend.service -n 20 --no-pager
    exit 1
fi

# Check frontend
if systemctl is-active --quiet inventory-frontend.service; then
    print_success "Frontend service is running"
else
    print_error "Frontend service failed to start - checking logs..."
    journalctl -u inventory-frontend.service -n 20 --no-pager
    exit 1
fi

# Check MongoDB
if systemctl is-active --quiet mongod; then
    print_success "MongoDB is running"
else
    print_error "MongoDB is not running"
    exit 1
fi

# Get local IP
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo -e "${GREEN}                    ✅ INSTALLATION COMPLETE!${NC}"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}📊 Service Status:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

systemctl status inventory-backend.service --no-pager | grep "Active"
systemctl status inventory-frontend.service --no-pager | grep "Active"
systemctl status mongod --no-pager | grep "Active"

echo ""
echo -e "${GREEN}🌐 Access URLs:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Frontend:    ${BLUE}http://$LOCAL_IP:3000${NC}"
echo "  Backend:     ${BLUE}http://$LOCAL_IP:5000${NC}"
echo "  API Health:  ${BLUE}http://$LOCAL_IP:5000/api/health${NC}"
echo ""
echo -e "${GREEN}📁 Application Location:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ${BLUE}/opt/inventory-app${NC}"
echo ""
echo -e "${GREEN}💾 Database:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  MongoDB:     ${BLUE}mongodb://localhost:27017/inventory_db${NC}"
echo ""
echo -e "${GREEN}🔧 Useful Commands:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  View backend logs:"
echo "    ${BLUE}sudo journalctl -u inventory-backend.service -f${NC}"
echo ""
echo "  View frontend logs:"
echo "    ${BLUE}sudo journalctl -u inventory-frontend.service -f${NC}"
echo ""
echo "  Restart backend:"
echo "    ${BLUE}sudo systemctl restart inventory-backend.service${NC}"
echo ""
echo "  Stop backend:"
echo "    ${BLUE}sudo systemctl stop inventory-backend.service${NC}"
echo ""
echo "  Firewall status:"
echo "    ${BLUE}sudo ufw status${NC}"
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo -e "${YELLOW}⏳ Waiting for services to fully initialize...${NC}"
sleep 3

# Test API
echo ""
echo -e "${YELLOW}🧪 Testing API...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/health)

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✅ API is responding correctly${NC}"
else
    echo -e "${YELLOW}⚠️  API response code: $HTTP_CODE (may be initializing)${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}🎉 READY TO USE!${NC}"
echo ""
echo "Open your browser and navigate to:"
echo ""
echo -e "  ${BLUE}${BOLD}http://$LOCAL_IP:3000${NC}"
echo ""
echo "Create a new account and start using the system!"
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo ""

# Create info file for future reference
cat > /opt/inventory-app/INSTALLATION_INFO.txt << EOF
Inventory Management System - Installation Info
================================================

Installation Date: $(date)
Installed on: $(hostname)
Local IP: $LOCAL_IP

Services:
  - inventory-backend.service (Port 5000)
  - inventory-frontend.service (Port 3000)
  - MongoDB (Port 27017)

Application Path: /opt/inventory-app
Database: mongodb://localhost:27017/inventory_db

View logs:
  sudo journalctl -u inventory-backend.service -f
  sudo journalctl -u inventory-frontend.service -f

Restart services:
  sudo systemctl restart inventory-backend.service
  sudo systemctl restart inventory-frontend.service

Access: http://$LOCAL_IP:3000

EOF

print_success "Installation info saved to /opt/inventory-app/INSTALLATION_INFO.txt"

echo ""
exit 0
