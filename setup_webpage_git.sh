#!/bin/bash

# ============================================================
# Auto Web Server Setup Script
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

TOTAL_STEPS=11
CURRENT_STEP=0

print_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}[${PERCENT}%] Βήμα ${CURRENT_STEP}/${TOTAL_STEPS}: $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# ============================================================
# INPUTS
# ============================================================
echo ""
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║        🚀 Auto Web Server Setup - Debian VM             ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

read -p "$(echo -e ${YELLOW}"📦 Όνομα project (π.χ. happydot): "${NC})" PROJECT_NAME
read -p "$(echo -e ${YELLOW}"🔗 GitHub SSH URL (π.χ. git@github.com:user/repo.git): "${NC})" GITHUB_SSH
read -p "$(echo -e ${YELLOW}"🏷️  Label για SSH key (π.χ. myserver.gr): "${NC})" SSH_LABEL
read -p "$(echo -e ${YELLOW}"🌿 Branch (main ή master): "${NC})" GIT_BRANCH
read -p "$(echo -e ${YELLOW}"🔑 Webhook secret: "${NC})" WEBHOOK_SECRET

PROJECT_PATH="/var/www/${PROJECT_NAME}"

echo ""
echo -e "${BLUE}📋 Σύνοψη:${NC}"
echo -e "   Project:  ${BOLD}${PROJECT_NAME}${NC}"
echo -e "   Path:     ${BOLD}${PROJECT_PATH}${NC}"
echo -e "   GitHub:   ${BOLD}${GITHUB_SSH}${NC}"
echo -e "   Branch:   ${BOLD}${GIT_BRANCH}${NC}"
echo -e "   SSH Key:  ${BOLD}${SSH_LABEL}${NC}"
echo ""
read -p "$(echo -e ${YELLOW}"Συνέχεια; (y/n): "${NC})" CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Ακυρώθηκε."
    exit 0
fi

# ============================================================
# STEP 1 - Update
# ============================================================
print_progress "Ενημέρωση συστήματος"
apt update && apt upgrade -y > /dev/null 2>&1 || print_error "Αποτυχία apt update"
print_success "Σύστημα ενημερώθηκε"

# ============================================================
# STEP 2 - Install packages
# ============================================================
print_progress "Εγκατάσταση Nginx, PHP, Git, Curl"
apt install nginx php-fpm php-cli git curl -y > /dev/null 2>&1 || print_error "Αποτυχία εγκατάστασης"
print_success "Πακέτα εγκαταστάθηκαν"

# ============================================================
# STEP 3 - Detect PHP version & start services
# ============================================================
print_progress "Εκκίνηση Nginx & PHP-FPM"
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
print_success "PHP έκδοση: ${PHP_VERSION}"

systemctl start nginx php${PHP_VERSION}-fpm > /dev/null 2>&1 || print_error "Αποτυχία εκκίνησης"
systemctl enable nginx php${PHP_VERSION}-fpm > /dev/null 2>&1
print_success "Nginx & PHP-FPM ενεργά"

# ============================================================
# STEP 4 - SSH Key
# ============================================================
print_progress "Δημιουργία SSH Key"
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -C "${SSH_LABEL}" -f ~/.ssh/id_ed25519 -N "" > /dev/null 2>&1
fi
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_ed25519.pub)
print_success "SSH Key δημιουργήθηκε"

# ============================================================
# STEP 5 - Clone repo
# ============================================================
print_progress "Clone GitHub repo"
cd /var/www
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null

echo ""
echo -e "${YELLOW}⚠️  Πρόσθεσε το παρακάτω SSH key στο GitHub repo → Settings → Deploy keys:${NC}"
echo ""
echo -e "${BOLD}${GREEN}${SSH_PUBLIC_KEY}${NC}"
echo ""
read -p "$(echo -e ${YELLOW}"Πάτα Enter αφού προσθέσεις το key στο GitHub...${NC})"

git clone ${GITHUB_SSH} ${PROJECT_NAME} || print_error "Αποτυχία clone"
chown -R www-data:www-data ${PROJECT_PATH}
print_success "Repo cloned στο ${PROJECT_PATH}"

# ============================================================
# STEP 6 - Webhook script
# ============================================================
print_progress "Δημιουργία webhook deploy script"
mkdir -p /var/www/webhook
cat > /var/www/webhook/deploy.php << PHPEOF
<?php
\$secret = "${WEBHOOK_SECRET}";
\$payload = file_get_contents('php://input');
\$signature = 'sha256=' . hash_hmac('sha256', \$payload, \$secret);
if (!hash_equals(\$signature, \$_SERVER['HTTP_X_HUB_SIGNATURE_256'] ?? '')) {
    http_response_code(403);
    die('Unauthorized');
}
exec('sudo -u root git -C ${PROJECT_PATH} fetch origin ${GIT_BRANCH} && sudo -u root git -C ${PROJECT_PATH} reset --hard origin/${GIT_BRANCH} 2>&1', \$output);
file_put_contents('/tmp/deploy.log', implode("\n", \$output));
echo implode("\n", \$output);
PHPEOF
print_success "Webhook script δημιουργήθηκε"

# ============================================================
# STEP 7 - Nginx config
# ============================================================
print_progress "Ρύθμιση Nginx"
cat > /etc/nginx/sites-available/${PROJECT_NAME} << NGINXEOF
server {
    listen 80;
    listen [::]:80;
    server_name _;

    root ${PROJECT_PATH};
    index index.html index.htm index.php;

    access_log /var/log/nginx/${PROJECT_NAME}_access.log;
    error_log  /var/log/nginx/${PROJECT_NAME}_error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location = /webhook/deploy.php {
        root /var/www;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME /var/www/webhook/deploy.php;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINXEOF
print_success "Nginx config δημιουργήθηκε"

# ============================================================
# STEP 8 - Enable site
# ============================================================
print_progress "Ενεργοποίηση site"
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/${PROJECT_NAME} /etc/nginx/sites-enabled/
nginx -t > /dev/null 2>&1 || print_error "Nginx config error"
systemctl reload nginx
print_success "Site ενεργοποιήθηκε"

# ============================================================
# STEP 9 - Sudo & safe directory
# ============================================================
print_progress "Ρύθμιση permissions"
echo "www-data ALL=(root) NOPASSWD: /usr/bin/git" >> /etc/sudoers
git config --global --add safe.directory ${PROJECT_PATH}
print_success "Permissions ρυθμίστηκαν"

# ============================================================
# STEP 10 - Install cloudflared
# ============================================================
print_progress "Εγκατάσταση Cloudflare Tunnel"
curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
dpkg -i /tmp/cloudflared.deb > /dev/null 2>&1 || print_error "Αποτυχία εγκατάστασης cloudflared"
print_success "Cloudflared εγκαταστάθηκε"

# ============================================================
# STEP 11 - Start Cloudflare Tunnel
# ============================================================
print_progress "Εκκίνηση Cloudflare Tunnel"
echo ""
echo -e "${YELLOW}⏳ Αναμονή για Cloudflare URL...${NC}"

CLOUDFLARE_URL=$(cloudflared tunnel --url http://localhost:80 2>&1 &
sleep 8
cloudflared tunnel --url http://localhost:80 2>&1 | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | head -1)

# Start tunnel in background and capture URL
cloudflared tunnel --url http://localhost:80 > /tmp/cloudflared.log 2>&1 &
CLOUDFLARED_PID=$!
sleep 8
CLOUDFLARE_URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cloudflared.log | head -1)

# ============================================================
# FINAL SUMMARY
# ============================================================
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                  ✅ SETUP ΟΛΟΚΛΗΡΩΘΗΚΕ!                ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}📋 ΣΤΟΙΧΕΙΑ ΕΓΚΑΤΑΣΤΑΣΗΣ:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}🔑 SSH Public Key (πρόσθεσε στο GitHub Deploy Keys):${NC}"
echo -e "${BOLD}${SSH_PUBLIC_KEY}${NC}"
echo ""
echo -e "${YELLOW}🌐 Cloudflare Tunnel URL:${NC}"
echo -e "${BOLD}${GREEN}${CLOUDFLARE_URL}${NC}"
echo ""
echo -e "${YELLOW}🔗 GitHub Webhook URL:${NC}"
echo -e "${BOLD}${GREEN}${CLOUDFLARE_URL}/webhook/deploy.php${NC}"
echo ""
echo -e "${YELLOW}🔑 Webhook Secret:${NC}"
echo -e "${BOLD}${WEBHOOK_SECRET}${NC}"
echo ""
echo -e "${YELLOW}📁 Project Path:${NC} ${PROJECT_PATH}"
echo -e "${YELLOW}🌿 Branch:${NC} ${GIT_BRANCH}"
echo -e "${YELLOW}🐘 PHP Version:${NC} ${PHP_VERSION}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${CYAN}📌 Επόμενα βήματα:${NC}"
echo -e "   1. Πρόσθεσε το SSH key στο GitHub repo → Settings → Deploy keys"
echo -e "   2. Πρόσθεσε το Webhook URL στο GitHub repo → Settings → Webhooks"
echo -e "   3. Content type: application/json"
echo -e "   4. Secret: ${WEBHOOK_SECRET}"
echo ""
echo -e "${RED}⚠️  Σημείωση: Το Cloudflare tunnel τρέχει στο background (PID: ${CLOUDFLARED_PID})${NC}"
echo -e "${RED}   Το URL αλλάζει κάθε φορά που κάνεις restart!${NC}"
echo ""
