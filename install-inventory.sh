#!/bin/bash

################################################################################
#                                                                              #
#  🚀 INVENTORY MANAGEMENT SYSTEM - COMPLETE GITHUB INSTALLATION              #
#  One Command Setup - Downloads Everything from GitHub                       #
#                                                                              #
#  Usage:                                                                      #
#  curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/proxmox_scripts/master/install.sh | bash
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
TOTAL_STEPS=13

print_header() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  🚀 INVENTORY MANAGEMENT SYSTEM - GITHUB INSTALLATION      ║"
    echo "║  Complete Debian 11/12 Setup - One Command                ║"
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
    echo "Try: sudo bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/proxmox_scripts/master/install.sh)"
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
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/debian bullseye/mongodb-org/6.0 main" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list > /dev/null
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
# STEP 4: Download Application from GitHub
# ═══════════════════════════════════════════════════════════════════════════

print_step "Downloading Application from GitHub"

GITHUB_USERNAME="pan07gaz94"  # Change this to your GitHub username
GITHUB_REPO="proxmox_scripts"
GITHUB_BRANCH="master"
GITHUB_URL="https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}/archive/refs/heads/${GITHUB_BRANCH}.zip"

print_info "Downloading from: $GITHUB_URL"

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download the repository as ZIP
if ! curl -fsSL "$GITHUB_URL" -o repo.zip; then
    print_error "Failed to download from GitHub"
    print_info "Make sure the repository exists and is public:"
    echo "  https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}"
    exit 1
fi

# Extract ZIP
unzip -q repo.zip
EXTRACTED_DIR=$(ls -d */ | head -1)

print_success "Repository downloaded and extracted"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 5: Create Application Directory
# ═══════════════════════════════════════════════════════════════════════════

print_step "Setting Up Application Directory"

mkdir -p /opt/inventory-app
cd /opt/inventory-app

# Copy application files
if [ -d "$TEMP_DIR/$EXTRACTED_DIR/inventory-app" ]; then
    print_info "Found inventory-app folder"
    cp -r "$TEMP_DIR/$EXTRACTED_DIR/inventory-app"/* /opt/inventory-app/
elif [ -d "$TEMP_DIR/$EXTRACTED_DIR" ]; then
    print_info "Checking for application files in repository root"
    # Check if package.json exists in root (app might be in root)
    if [ -f "$TEMP_DIR/$EXTRACTED_DIR/package.json" ]; then
        cp -r "$TEMP_DIR/$EXTRACTED_DIR"/* /opt/inventory-app/
    else
        print_error "Could not find inventory-app folder in repository"
        echo ""
        echo "Repository structure should be:"
        echo "  proxmox_scripts/"
        echo "  ├─ inventory-app/"
        echo "  │  ├─ server.js"
        echo "  │  ├─ package.json"
        echo "  │  ├─ client/"
        echo "  │  ├─ models/"
        echo "  │  └─ routes/"
        echo "  └─ install.sh"
        exit 1
    fi
fi

# Verify package.json
if [ ! -f "/opt/inventory-app/package.json" ]; then
    print_error "package.json not found - application files incomplete"
    ls -la /opt/inventory-app/
    exit 1
fi

print_success "Application files ready at /opt/inventory-app"

# Clean up temp directory
rm -rf "$TEMP_DIR"

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
print_info "JWT_SECRET: ${JWT_SECRET:0:16}...****"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 7: Install Backend Dependencies
# ═══════════════════════════════════════════════════════════════════════════

print_step "Installing Backend Dependencies"
cd /opt/inventory-app

npm install --omit=dev --silent

print_success "Backend dependencies installed"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 8: Install Frontend Dependencies
# ═══════════════════════════════════════════════════════════════════════════

print_step "Installing Frontend Dependencies"

if [ ! -d "client" ]; then
    print_error "client folder not found"
    exit 1
fi

cd /opt/inventory-app/client
npm install --omit=dev --silent

print_success "Frontend dependencies installed"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 9: Build Frontend
# ═══════════════════════════════════════════════════════════════════════════

print_step "Building Frontend Application"

npm run build

print_success "Frontend built successfully"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 10: Create Systemd Services
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

print_success "Systemd services created and enabled"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 11: Configure Firewall
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
# STEP 12: Start Services
# ═══════════════════════════════════════════════════════════════════════════

print_step "Starting Services"

systemctl start inventory-backend.service
sleep 4

systemctl start inventory-frontend.service
sleep 3

print_success "Backend service started"
print_success "Frontend service started"

# ═══════════════════════════════════════════════════════════════════════════
# STEP 13: Verification & Final Output
# ═══════════════════════════════════════════════════════════════════════════

print_step "Verifying Installation"

BACKEND_OK=false
FRONTEND_OK=false
MONGO_OK=false

if systemctl is-active --quiet inventory-backend.service; then
    print_success "Backend service is running ✓"
    BACKEND_OK=true
else
    print_error "Backend service failed to start"
    journalctl -u inventory-backend.service -n 20 --no-pager
fi

if systemctl is-active --quiet inventory-frontend.service; then
    print_success "Frontend service is running ✓"
    FRONTEND_OK=true
else
    print_error "Frontend service failed to start"
    journalctl -u inventory-frontend.service -n 20 --no-pager
fi

if systemctl is-active --quiet mongod; then
    print_success "MongoDB is running ✓"
    MONGO_OK=true
else
    print_error "MongoDB is not running"
fi

if [ "$BACKEND_OK" = false ] || [ "$FRONTEND_OK" = false ] || [ "$MONGO_OK" = false ]; then
    print_error "Installation verification failed"
    exit 1
fi

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
echo -e "${GREEN}🌐 Access Your Application:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${BLUE}http://$LOCAL_IP:3000${NC}"
echo ""
echo "  Open this URL in your browser:"
echo "  1. Create a new account"
echo "  2. Start using the system"
echo ""
echo -e "${GREEN}📊 Service URLs:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
echo "  ${BLUE}mongodb://localhost:27017/inventory_db${NC}"
echo ""
echo -e "${GREEN}🔧 Useful Commands:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  View backend logs:"
echo "    ${BLUE}sudo journalctl -u inventory-backend.service -f${NC}"
echo ""
echo "  Restart backend:"
echo "    ${BLUE}sudo systemctl restart inventory-backend.service${NC}"
echo ""
echo "  Stop backend:"
echo "    ${BLUE}sudo systemctl stop inventory-backend.service${NC}"
echo ""
echo "  Check status:"
echo "    ${BLUE}sudo systemctl status inventory-backend.service${NC}"
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo -e "${YELLOW}⏳ Waiting for services to fully initialize...${NC}"
sleep 3

# Test API
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/health 2>/dev/null || echo "000")

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✅ API is responding correctly (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${YELLOW}⚠️  API response code: $HTTP_CODE (may still be initializing)${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo -e "${GREEN}🎉 SYSTEM IS READY TO USE!${NC}"
echo ""
echo "Next steps:"
echo "  1. Open: http://$LOCAL_IP:3000"
echo "  2. Create a new account"
echo "  3. Start managing your inventory!"
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
GitHub Repo: https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}

Services:
  - inventory-backend.service (Port 5000)
  - inventory-frontend.service (Port 3000)
  - MongoDB (Port 27017)

Application: /opt/inventory-app
Database: mongodb://localhost:27017/inventory_db

Access: http://$LOCAL_IP:3000

Useful Commands:
  View logs: sudo journalctl -u inventory-backend.service -f
  Restart: sudo systemctl restart inventory-backend.service
  Stop: sudo systemctl stop inventory-backend.service
  Status: sudo systemctl status inventory-backend.service

For support, visit: https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}

EOF

print_success "Installation info saved to /opt/inventory-app/INSTALLATION_INFO.txt"

exit 0
