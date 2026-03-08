#!/bin/bash

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

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error()   { echo -e "${RED}❌ $1${NC}"; exit 1; }

echo ""
echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║        🚀 Auto Web Server Setup - Debian VM             ║${NC}"
echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

read -p "📦 Όνομα project (π.χ. mypage): " PROJECT_NAME
read -p "🔗 GitHub SSH URL: " GITHUB_SSH
read -p "🏷️  Label για SSH key: " SSH_LABEL
read -p "🌿 Branch (main ή master): " GIT_BRANCH
read -p "🔑 Webhook secret: " WEBHOOK_SECRET

PROJECT_PATH="/var/www/${PROJECT_NAME}"

echo ""
echo -e "${BLUE}📋 Σύνοψη:${NC}"
echo -e "   Project:  ${BOLD}${PROJECT_NAME}${NC}"
echo -e "   Path:     ${BOLD}${PROJECT_PATH}${NC}"
echo -e "   GitHub:   ${BOLD}${GITHUB_SSH}${NC}"
echo -e "   Branch:   ${BOLD}${GIT_BRANCH}${NC}"
echo ""
read -p "Συνέχεια; (y/n): " CONFIRM
[ "$CONFIRM" != "y" ] && echo "Ακυρώθηκε." && exit 0

# STEP 1
print_progress "Ενημέρωση συστήματος"
apt update && apt upgrade -y > /dev/null 2>&1 || print_error "Αποτυχία apt update"
print_success "Σύστημα ενημερώθηκε"

# STEP 2
print_progress "Εγκατάσταση Nginx, PHP, Git, Curl"
apt install nginx php-fpm php-cli git curl -y > /dev/null 2>&1 || print_error "Αποτυχία εγκατάστασης"
print_success "Πακέτα εγκαταστάθηκαν"

# STEP 3
print_progress "Εκκίνηση Nginx & PHP-FPM"
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
print_success "PHP έκδοση: ${PHP_VERSION}"
systemctl start nginx "php${PHP_VERSION}-fpm" > /dev/null 2>&1 || print_error "Αποτυχία εκκίνησης"
systemctl enable nginx "php${PHP_VERSION}-fpm" > /dev/null 2>&1
print_success "Nginx & PHP-FPM ενεργά"

# STEP 4
print_progress "Δημιουργία SSH Key"
[ ! -f ~/.ssh/id_ed25519 ] && ssh-keygen -t ed25519 -C "${SSH_LABEL}" -f ~/.ssh/id_ed25519 -N "" > /dev/null 2>&1
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_ed25519.pub)
print_success "SSH Key δημιουργήθηκε"

# STEP 5
print_progress "Clone GitHub repo"
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
echo ""
echo -e "${YELLOW}⚠️  Πρόσθεσε το παρακάτω SSH key στο GitHub repo → Settings → Deploy keys:${NC}"
echo ""
echo -e "${BOLD}${GREEN}${SSH_PUBLIC_KEY}${NC}"
echo ""
read -p "Πάτα Enter αφού προσθέσεις το key στο GitHub..."
cd /var/www || print_error "Αποτυχία cd"
git clone "${GITHUB_SSH}" "${PROJECT_NAME}" || print_error "Αποτυχία clone"
chown -R www-data:www-data "${PROJECT_PATH}"
print_success "Repo cloned"

# STEP 6
print_progress "Δημιουργία webhook deploy script"
mkdir -p /var/www/webhook
DEPLOY_PHP="/var/www/webhook/deploy.php"
printf '%s\n' '<?php' > "$DEPLOY_PHP"
printf '$secret = "%s";\n' "${WEBHOOK_SECRET}" >> "$DEPLOY_PHP"
printf '%s\n' '$payload = file_get_contents("php://input");' >> "$DEPLOY_PHP"
printf '%s\n' '$signature = "sha256=" . hash_hmac("sha256", $payload, $secret);' >> "$DEPLOY_PHP"
printf '%s\n' 'if (!hash_equals($signature, $_SERVER["HTTP_X_HUB_SIGNATURE_256"] ?? "")) {' >> "$DEPLOY_PHP"
printf '%s\n' '    http_response_code(403);' >> "$DEPLOY_PHP"
printf '%s\n' '    die("Unauthorized");' >> "$DEPLOY_PHP"
printf '%s\n' '}' >> "$DEPLOY_PHP"
printf 'exec("sudo -u root git -C %s fetch origin %s && sudo -u root git -C %s reset --hard origin/%s 2>&1", $output);\n' "${PROJECT_PATH}" "${GIT_BRANCH}" "${PROJECT_PATH}" "${GIT_BRANCH}" >> "$DEPLOY_PHP"
printf '%s\n' 'file_put_contents("/tmp/deploy.log", implode("\n", $output));' >> "$DEPLOY_PHP"
printf '%s\n' 'echo implode("\n", $output);' >> "$DEPLOY_PHP"
print_success "Webhook script δημιουργήθηκε"

# STEP 7
print_progress "Ρύθμιση Nginx"
NGINX_CONF="/etc/nginx/sites-available/${PROJECT_NAME}"
{
echo "server {"
echo "    listen 80;"
echo "    listen [::]:80;"
echo "    server_name _;"
echo ""
echo "    root ${PROJECT_PATH};"
echo "    index index.html index.htm index.php;"
echo ""
echo "    access_log /var/log/nginx/${PROJECT_NAME}_access.log;"
echo "    error_log  /var/log/nginx/${PROJECT_NAME}_error.log;"
echo ""
echo "    location / {"
echo "        try_files \$uri \$uri/ =404;"
echo "    }"
echo ""
echo "    location ~ \.php\$ {"
echo "        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;"
echo "        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;"
echo "        include fastcgi_params;"
echo "    }"
echo ""
echo "    location = /webhook/deploy.php {"
echo "        root /var/www;"
echo "        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;"
echo "        fastcgi_param SCRIPT_FILENAME /var/www/webhook/deploy.php;"
echo "        include fastcgi_params;"
echo "    }"
echo ""
echo "    location ~ /\.ht {"
echo "        deny all;"
echo "    }"
echo "}"
} > "$NGINX_CONF"
print_success "Nginx config δημιουργήθηκε"

# STEP 8
print_progress "Ενεργοποίηση site"
rm -f /etc/nginx/sites-enabled/default
ln -sf "/etc/nginx/sites-available/${PROJECT_NAME}" "/etc/nginx/sites-enabled/${PROJECT_NAME}"
nginx -t > /dev/null 2>&1 || print_error "Nginx config error"
systemctl reload nginx
print_success "Site ενεργοποιήθηκε"

# STEP 9
print_progress "Ρύθμιση permissions"
echo "www-data ALL=(root) NOPASSWD: /usr/bin/git" >> /etc/sudoers
git config --global --add safe.directory "${PROJECT_PATH}"
print_success "Permissions ρυθμίστηκαν"

# STEP 10
print_progress "Εγκατάσταση Cloudflare Tunnel"
curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
dpkg -i /tmp/cloudflared.deb > /dev/null 2>&1 || print_error "Αποτυχία cloudflared"
print_success "Cloudflared εγκαταστάθηκε"

# STEP 11
print_progress "Εκκίνηση Cloudflare Tunnel"
echo -e "${YELLOW}⏳ Αναμονή για Cloudflare URL...${NC}"
cloudflared tunnel --url http://localhost:80 > /tmp/cloudflared.log 2>&1 &
CLOUDFLARED_PID=$!
sleep 10
CLOUDFLARE_URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cloudflared.log | head -1)
[ -z "$CLOUDFLARE_URL" ] && CLOUDFLARE_URL="(έλεγξε: cat /tmp/cloudflared.log)"
print_success "Cloudflare Tunnel ενεργό"

# SUMMARY
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                  ✅ SETUP ΟΛΟΚΛΗΡΩΘΗΚΕ!                ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}🔑 SSH Public Key:${NC}"
echo -e "${BOLD}${GREEN}${SSH_PUBLIC_KEY}${NC}"
echo ""
echo -e "${YELLOW}🌐 Cloudflare URL:${NC}     ${BOLD}${GREEN}${CLOUDFLARE_URL}${NC}"
echo -e "${YELLOW}🔗 Webhook URL:${NC}        ${BOLD}${GREEN}${CLOUDFLARE_URL}/webhook/deploy.php${NC}"
echo -e "${YELLOW}🔑 Webhook Secret:${NC}     ${BOLD}${WEBHOOK_SECRET}${NC}"
echo -e "${YELLOW}📁 Project Path:${NC}       ${PROJECT_PATH}"
echo -e "${YELLOW}🌿 Branch:${NC}             ${GIT_BRANCH}"
echo -e "${YELLOW}🐘 PHP Version:${NC}        ${PHP_VERSION}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${CYAN}📌 Επόμενα βήματα στο GitHub:${NC}"
echo -e "   Settings → Webhooks → Add webhook"
echo -e "   Payload URL:  ${BOLD}${CLOUDFLARE_URL}/webhook/deploy.php${NC}"
echo -e "   Content type: ${BOLD}application/json${NC}"
echo -e "   Secret:       ${BOLD}${WEBHOOK_SECRET}${NC}"
echo ""
echo -e "${RED}⚠️  Το tunnel τρέχει background (PID: ${CLOUDFLARED_PID}) - URL αλλάζει στο restart!${NC}"
echo ""
