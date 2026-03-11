╔════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║  🚀 INVENTORY MANAGEMENT SYSTEM - ONE COMMAND INSTALLATION                ║
║                                                                            ║
║  ΜΙΑ ΕΝΤΟΛΉ - ΟΛΟΣ Ο SETUP!                                               ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════════════════════════

⚡ THE ONE COMMAND:

SSH to your Debian VM and run EXACTLY this:

curl -fsSL https://raw.githubusercontent.com/pan07gaz94/proxmox_scripts/refs/heads/master/install-inventory.sh | sudo bash

That's it! Nothing else needed!

═══════════════════════════════════════════════════════════════════════════════

📋 STEP-BY-STEP:

1. SSH to your Debian 11/12 VM:
   
   ssh user@your-vm-ip

2. Run the one-liner:
   
   curl -fsSL https://raw.githubusercontent.com/pan07gaz94/proxmox_scripts/refs/heads/master/install-inventory.sh | sudo bash

3. Wait 15-20 minutes while it:
   - Updates system
   - Installs Node.js v18
   - Installs MongoDB
   - Downloads app from GitHub
   - Installs dependencies
   - Builds frontend
   - Creates services
   - Starts everything

4. When done, you'll see:
   
   ✅ INSTALLATION COMPLETE!
   
   🌐 OPEN YOUR BROWSER:
   http://your-vm-ip:3000

5. Create account and enjoy! 🎉

═══════════════════════════════════════════════════════════════════════════════

🎯 THE ONE COMMAND EXPLAINED:

curl -fsSL https://raw.githubusercontent.com/pan07gaz94/proxmox_scripts/refs/heads/master/install-inventory.sh | sudo bash

What it does:
  - curl = Download the script silently
  - fsSL = Follow redirects, no progress bar
  - https://... = GitHub raw URL to our script
  - | sudo bash = Execute immediately with sudo

NO manual steps
NO intermediate files
NO downloading
EVERYTHING AUTOMATIC!

═══════════════════════════════════════════════════════════════════════════════

✨ WHAT HAPPENS WHEN YOU RUN IT:

The script automatically:

1. Updates system packages
2. Installs Node.js v18 LTS
3. Installs MongoDB Community
4. Downloads the complete app from GitHub
5. Sets up environment (.env)
6. Installs npm dependencies
7. Builds the React frontend
8. Creates systemd services (auto-start on reboot)
9. Configures UFW firewall
10. Starts all services
11. Verifies everything works
12. Shows you the access URL

═══════════════════════════════════════════════════════════════════════════════

🌐 AFTER INSTALLATION:

Open your browser:
  http://your-vm-ip:3000

Create a new account and start using!

═══════════════════════════════════════════════════════════════════════════════

⏱️ TOTAL TIME: 15-20 MINUTES

From zero to production:
  - System update: 2 min
  - Node.js + MongoDB: 5 min
  - npm install: 5 min
  - Build + Services: 5 min
  - Verification: 1 min

═══════════════════════════════════════════════════════════════════════════════

📊 WHAT GETS INSTALLED:

✓ Node.js v18 LTS
✓ MongoDB Community Edition
✓ Inventory Management System
  - Backend (Express.js, port 5000)
  - Frontend (React, port 3000)
  - Database (MongoDB, port 27017)
✓ Systemd Services (auto-start)
✓ UFW Firewall
✓ All npm dependencies

Location: /opt/inventory-app

═══════════════════════════════════════════════════════════════════════════════

🔧 USEFUL COMMANDS AFTER INSTALLATION:

View backend logs:
  sudo journalctl -u inventory-backend.service -f

Restart backend:
  sudo systemctl restart inventory-backend.service

Stop backend:
  sudo systemctl stop inventory-backend.service

Check status:
  sudo systemctl status inventory-backend.service

View installation info:
  cat /opt/inventory-app/INSTALLATION_INFO.txt

═══════════════════════════════════════════════════════════════════════════════

❓ FAQ:

Q: What if I get an error?
A: Check the logs: sudo journalctl -u inventory-backend.service -f

Q: How do I know it's working?
A: Open http://your-vm-ip:3000 in your browser

Q: Can I run it multiple times?
A: Yes, it's safe to run multiple times

Q: Where are the files?
A: /opt/inventory-app

Q: Can I access from other computers?
A: Yes, use your VM's IP address instead of localhost

Q: What's the login?
A: Create a new account on first access

Q: How do I backup the database?
A: MongoDB data is in /var/lib/mongodb

Q: How do I uninstall?
A: Remove /opt/inventory-app and disable services:
   sudo rm -rf /opt/inventory-app
   sudo systemctl disable inventory-backend.service

═══════════════════════════════════════════════════════════════════════════════

🎉 THAT'S ALL YOU NEED!

Just run:

curl -fsSL https://raw.githubusercontent.com/pan07gaz94/proxmox_scripts/refs/heads/master/install-inventory.sh | sudo bash

Wait 15-20 minutes.

Open http://your-vm-ip:3000.

Enjoy! 🚀

═══════════════════════════════════════════════════════════════════════════════

GitHub Repository:
  https://github.com/pan07gaz94/proxmox_scripts

Version: 1.0.0
Status: Production-Ready ✅

═══════════════════════════════════════════════════════════════════════════════
