#!/bin/bash

set -e

echo "========================================="
echo "SSH Complete Setup Script για Debian"
echo "========================================="
echo ""

# ============================================
# ΒΗΜΑ 1: Ενημέρωση και εγκατάσταση
# ============================================
echo "[1/6] Ενημέρωση package lists..."
apt update -qq

echo "[2/6] Εγκατάσταση OpenSSH Server..."
apt install -y openssh-server > /dev/null 2>&1

# ============================================
# ΒΗΜΑ 2: Ρύθμιση κωδικού για root
# ============================================
echo ""
echo "========================================="
echo "ΡΥΘΜΙΣΗ ΚΩΔΙΚΟΥ ROOT"
echo "========================================="
echo ""

# Δημιουργία ενός secure κωδικού
SSH_PASSWORD="${SSH_PASSWORD:-$(openssl rand -base64 12)}"

echo "Root κωδικός: $SSH_PASSWORD"
echo ""

# Ορισμός κωδικού χωρίς αλληλεπιδραση
echo "root:$SSH_PASSWORD" | chpasswd

echo "✓ Κωδικός ορίστηκε επιτυχώς"
echo ""

# ============================================
# ΒΗΜΑ 3: Ρύθμιση SSH Configuration
# ============================================
echo "[3/6] Ρύθμιση SSH configuration..."

# Backup του αρχικού αρχείου
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Αντικατάσταση των απαραίτητων παραμέτρων
sed -i 's/^#Port 22/Port 22/' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Προσθήκη επιπλέον ασφαλείας
grep -q "PubkeyAuthentication yes" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
grep -q "StrictModes yes" /etc/ssh/sshd_config || echo "StrictModes yes" >> /etc/ssh/sshd_config
grep -q "MaxAuthTries 6" /etc/ssh/sshd_config || echo "MaxAuthTries 6" >> /etc/ssh/sshd_config
grep -q "X11Forwarding yes" /etc/ssh/sshd_config || echo "X11Forwarding yes" >> /etc/ssh/sshd_config

echo "✓ SSH configuration ενημερώθηκε"
echo ""

# ============================================
# ΒΗΜΑ 4: Ενεργοποίηση και εκκίνηση SSH
# ============================================
echo "[4/6] Ενεργοποίηση και εκκίνηση SSH service..."
systemctl enable ssh > /dev/null 2>&1
systemctl restart ssh > /dev/null 2>&1
systemctl status ssh --no-pager | head -n 3

echo ""

# ============================================
# ΒΗΜΑ 5: IP Detection
# ============================================
echo "[5/6] Ανίχνευση IP διεύθυνσης..."
echo ""

# Εύρεση της κύριας IP διεύθυνσης
SSH_IP=$(hostname -I | awk '{print $1}')

if [ -z "$SSH_IP" ]; then
    SSH_IP=$(ip route get 1 2>/dev/null | awk '{print $NF;exit}')
fi

# Fallback αν δεν βρεθεί IP
if [ -z "$SSH_IP" ]; then
    SSH_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
fi

echo "IP Διεύθυνση: $SSH_IP"
echo "SSH Username: root"
echo "SSH Password: $SSH_PASSWORD"
echo ""

# ============================================
# ΒΗΜΑ 6: Έλεγχος ακρόασης
# ============================================
echo "[6/6] Έλεγχος ακρόασης στη θύρα 22..."
if ss -tuln 2>/dev/null | grep -q ":22 "; then
    echo "✓ SSH ακούει στη θύρα 22"
else
    echo "⚠ Προσοχή: SSH δεν φαίνεται να ακούει"
fi
echo ""

# ============================================
# ΤΕΛΙΚΑ ΣΤΟΙΧΕΙΑ ΣΥΝΔΕΣΗΣ
# ============================================
echo "========================================="
echo "✓ SSH SETUP ΟΛΟΚΛΗΡΩΘΗΚΕ!"
echo "========================================="
echo ""
echo "ΣΤΟΙΧΕΙΑ ΣΥΝΔΕΣΗΣ SSH:"
echo "========================================="
echo "Hostname/IP: $SSH_IP"
echo "Username:    root"
echo "Password:    $SSH_PASSWORD"
echo "Port:        22"
echo "========================================="
echo ""
echo "ΕΝΤΟΛΗ ΣΥΝΔΕΣΗΣ:"
echo "ssh root@$SSH_IP"
echo ""
echo "ΕΝΤΟΛΗ ΓΙΑ ΑΠΟΣΤΟΛΗ ΚΛΕΙΔΙΟΥ (optional):"
echo "ssh-copy-id -i ~/.ssh/id_rsa.pub root@$SSH_IP"
echo ""
echo "========================================="
