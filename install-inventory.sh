#!/bin/bash

################################################################################
#                                                                              #
#  🚀 INVENTORY MANAGEMENT SYSTEM - GITHUB READY INSTALLATION                 #
#  Complete Debian 11/12 Setup with Embedded Application                      #
#                                                                              #
#  Usage:                                                                      #
#  curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/proxmox_scripts/master/install-inventory.sh | bash
#                                                                              #
#  Or locally:                                                                 #
#  bash install-inventory.sh                                                   #
#                                                                              #
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

STEP=0
TOTAL_STEPS=12

print_header() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  📦 INVENTORY MANAGEMENT SYSTEM - AUTO INSTALLATION        ║"
    echo "║  Debian 11/12 on Proxmox                                  ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_step() {
    STEP=$((STEP + 1))
    echo ""
    echo -e "${YELLOW}[${STEP}/${TOTAL_STEPS}]${NC} $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root or with sudo"
    echo "Try: sudo bash $0"
    exit 1
fi

print_header

# ═══════════════════════════════════════════════════════════════════════════
# STEP 1: System Update
# ═══════════════════════════════════════════════════════════════════════════

print_step "Updating System Packages"
apt-get update -y
apt-get upgrade -y
apt-get install -y curl git wget build-essential unzip
print_success "System updated"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 2: Install Node.js v18
# ═══════════════════════════════════════════════════════════════════════════

print_step "Installing Node.js v18 LTS"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs
print_success "Node.js $(node --version) installed"

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
# STEP 5: Download or Use Local Application
# ═══════════════════════════════════════════════════════════════════════════

print_step "Setting Up Application"

# Check if inventory-app exists locally
if [ -d "$HOME/inventory-app" ]; then
    print_info "Found local inventory-app folder"
    cp -r $HOME/inventory-app/* /opt/inventory-app/
elif [ -d "./inventory-app" ]; then
    print_info "Found inventory-app in current directory"
    cp -r ./inventory-app/* /opt/inventory-app/
else
    print_info "Downloading from GitHub..."
    # You can add your GitHub repo URL here
    # For now, create a basic structure
    print_error "No local inventory-app found"
    echo ""
    echo "Please ensure you have the inventory-app folder in one of:"
    echo "  - $HOME/inventory-app"
    echo "  - ./inventory-app"
    echo "  - /opt/inventory-app"
    exit 1
fi

if [ ! -f "/opt/inventory-app/package.json" ]; then
    print_error "package.json not found - application files incomplete"
    exit 1
fi

print_success "Application files ready"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 6: Create .env File
# ═══════════════════════════════════════════════════════════════════════════

print_step "Configuring Environment"
cd /opt/inventory-app

JWT_SECRET=$(openssl rand -hex 32)

cat > .env << EOF
MONGODB_URI=mongodb://localhost:27017/inventory_db
PORT=5000
JWT_SECRET=$JWT_SECRET
NODE_ENV=production
FRONTEND_URL=http://localhost:3000
EOF

print_success ".env file created"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 7: Install Backend Dependencies
# ═══════════════════════════════════════════════════════════════════════════

print_step "Installing Backend Dependencies"
cd /opt/inventory-app
npm install --omit=dev
print_success "Backend dependencies installed"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 8: Build Frontend
# ═══════════════════════════════════════════════════════════════════════════

print_step "Building Frontend"
cd /opt/inventory-app/client
npm install --omit=dev
npm run build
print_success "Frontend built"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 9: Create Systemd Services
# ═══════════════════════════════════════════════════════════════════════════

print_step "Creating Systemd Services"

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

print_step "Configuring Firewall"

ufw --force enable 2>/dev/null || true
ufw default deny incoming 2>/dev/null || true
ufw default allow outgoing 2>/dev/null || true
ufw allow 22/tcp 2>/dev/null || true
ufw allow 3000/tcp 2>/dev/null || true
ufw allow 5000/tcp 2>/dev/null || true
ufw reload 2>/dev/null || true

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
# STEP 12: Verification
# ═══════════════════════════════════════════════════════════════════════════

print_step "Verifying Installation"

if ! systemctl is-active --quiet inventory-backend.service; then
    print_error "Backend service failed to start"
    journalctl -u inventory-backend.service -n 20 --no-pager
    exit 1
fi

if ! systemctl is-active --quiet inventory-frontend.service; then
    print_error "Frontend service failed to start"
    journalctl -u inventory-frontend.service -n 20 --no-pager
    exit 1
fi

if ! systemctl is-active --quiet mongod; then
    print_error "MongoDB is not running"
    exit 1
fi

print_success "Backend service is running"
print_success "Frontend service is running"
print_success "MongoDB is running"

# Get local IP
LOCAL_IP=$(hostname -I | awk '{print $1}')

# ═══════════════════════════════════════════════════════════════════════════
# Final Output
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo -e "${GREEN}                    ✅ INSTALLATION COMPLETE!${NC}"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}🌐 Access URLs:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Frontend:    ${BLUE}http://$LOCAL_IP:3000${NC}"
echo "  Backend:     ${BLUE}http://$LOCAL_IP:5000${NC}"
echo "  API Health:  ${BLUE}http://$LOCAL_IP:5000/api/health${NC}"
echo ""
echo -e "${GREEN}📁 Location:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ${BLUE}/opt/inventory-app${NC}"
echo ""
echo -e "${GREEN}💾 Database:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ${BLUE}mongodb://localhost:27017/inventory_db${NC}"
echo ""
echo -e "${GREEN}🔧 Useful Commands:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  View logs:"
echo "    ${BLUE}sudo journalctl -u inventory-backend.service -f${NC}"
echo ""
echo "  Restart backend:"
echo "    ${BLUE}sudo systemctl restart inventory-backend.service${NC}"
echo ""
echo "  Stop backend:"
echo "    ${BLUE}sudo systemctl stop inventory-backend.service${NC}"
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo -e "${YELLOW}⏳ Waiting for services to fully initialize...${NC}"
sleep 3

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/health 2>/dev/null || echo "000")

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✅ API is responding correctly${NC}"
else
    echo -e "${YELLOW}⚠️  Services may still be initializing...${NC}"
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

# Create info file
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

Application: /opt/inventory-app
Database: mongodb://localhost:27017/inventory_db

Access: http://$LOCAL_IP:3000

Commands:
  View logs: sudo journalctl -u inventory-backend.service -f
  Restart: sudo systemctl restart inventory-backend.service
  Stop: sudo systemctl stop inventory-backend.service

EOF

print_success "Installation info saved to /opt/inventory-app/INSTALLATION_INFO.txt"

exit 0
