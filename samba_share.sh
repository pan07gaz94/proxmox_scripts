#!/bin/bash

# Script για ρύθμιση Samba κοινής χρήσης του /var/www
# Χρήση: bash setup-samba-www.sh
# Το script ανιχνεύει αυτόματα την IP του συστήματος

echo "================================"
echo "🚀 Ρύθμιση Samba για /var/www"
echo "================================"
echo ""

# Έλεγχος αν είναι root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Το script πρέπει να τρέχει ως root!"
    echo "Χρήση: sudo bash setup-samba-www.sh"
    exit 1
fi

# Ανίχνευση IP διεύθυνσης
echo "🔍 Ανίχνευση IP διεύθυνσης..."
SERVER_IP=$(hostname -I | awk '{print $1}')

if [ -z "$SERVER_IP" ]; then
    echo "❌ Δεν μπόρεσα να ανιχνεύσω την IP!"
    echo "Δοκίμασε να χρησιμοποιήσεις το 'ip addr show' για να βρεις την IP σου"
    exit 1
fi

echo "✅ IP ανιχνεύθηκε: $SERVER_IP"
echo ""

# 1. Ενημέρωση συστήματος
echo "📦 Ενημέρωση καταλόγου πακέτων..."
apt-get update -y

# 2. Εγκατάσταση Samba
echo "📥 Εγκατάσταση Samba..."
apt-get install -y samba samba-common

# 3. Δικαιώματα φακέλου www
echo "🔐 Ρύθμιση δικαιωμάτων /var/www..."
chmod -R 777 /var/www

# 4. Backup του αρχικού smb.conf
echo "💾 Backup του smb.conf..."
cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

# 5. Προσθήκη της κοινής χρήσης www
echo "✏️  Ρύθμιση Samba configuration..."

# Ελεγχος αν υπάρχει ήδη η κοινή χρήση [www]
if ! grep -q "^\[www\]" /etc/samba/smb.conf; then
    cat >> /etc/samba/smb.conf << 'EOF'

# Κοινή χρήση για /var/www (προστέθηκε αυτόματα)
[www]
    path = /var/www
    browseable = yes
    writable = yes
    guest ok = yes
    guest only = yes
    read only = no
    create mask = 0777
    directory mask = 0777
    force user = www-data
EOF
    echo "✅ Κοινή χρήση www προστέθηκε"
else
    echo "⚠️  Η κοινή χρήση www υπάρχει ήδη"
fi

# 6. Έλεγχος σύνταξης
echo "🔍 Έλεγχος σύνταξης smb.conf..."
testparm -s > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Σύνταξη OK"
else
    echo "❌ Σφάλμα στη σύνταξη smb.conf!"
    exit 1
fi

# 7. Επανεκκίνηση Samba
echo "🔄 Επανεκκίνηση Samba..."
systemctl restart smbd
systemctl restart nmbd

# 8. Ενεργοποίηση για μόνιμη εκκίνηση
echo "🔧 Ενεργοποίηση Samba στην εκκίνηση..."
systemctl enable smbd
systemctl enable nmbd

# 9. Έλεγχος κατάστασης
echo ""
echo "📊 Κατάσταση Samba:"
systemctl status smbd --no-pager

# 10. Πληροφορίες σύνδεσης
echo ""
echo "================================"
echo "✅ ΟΛΟΚΛΗΡΩΘΗΚΕ!"
echo "================================"
echo ""
echo "📍 Πληροφορίες σύνδεσης:"
echo "   IP: $SERVER_IP"
echo "   Κοινή χρήση: \\\\$SERVER_IP\\www"
echo "   Χρήστης: guest"
echo ""
echo "🍎 Για Mac:"
echo "   Cmd + K στο Finder"
echo "   smb://$SERVER_IP/www"
echo ""
echo "🪟 Για Windows:"
echo "   \\\\$SERVER_IP\\www"
echo ""
echo "🐧 Για Linux:"
echo "   smbclient //$SERVER_IP/www -U guest"
echo ""
echo "================================"
