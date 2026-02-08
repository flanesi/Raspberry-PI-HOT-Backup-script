#!/bin/bash
#
# Raspberry Pi HOT Backup System - Installer Script
# 
# This script installs system_backup and pishrink automatically
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
    echo ""
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

print_header "Raspberry Pi HOT Backup System - Installer"

echo "This script will install:"
echo "  • system_backup - Complete SD card backup tool"
echo "  • pishrink - Image size reduction tool"
echo ""
read -p "Continue with installation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Installation cancelled"
    exit 0
fi

# Detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
print_info "Installation directory: $SCRIPT_DIR"

# Step 1: Install dependencies
print_header "Step 1: Installing Dependencies"

print_info "Updating package list..."
apt-get update -qq

print_info "Installing required packages..."
PACKAGES="parted e2fsprogs"
for pkg in $PACKAGES; do
    if dpkg -l | grep -q "^ii  $pkg "; then
        print_success "$pkg already installed"
    else
        print_info "Installing $pkg..."
        apt-get install -y -qq $pkg
        print_success "$pkg installed"
    fi
done

# Step 2: Create directories
print_header "Step 2: Creating Directories"

INSTALL_DIR="/var/www/MyScripts"
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    print_success "Created $INSTALL_DIR"
else
    print_info "$INSTALL_DIR already exists"
fi

# Step 3: Copy scripts
print_header "Step 3: Installing Scripts"

# Find script files
SYSTEM_BACKUP_SRC=""
PISHRINK_SRC=""

# Look for scripts in current directory
if [ -f "$SCRIPT_DIR/system_backup.sh" ]; then
    SYSTEM_BACKUP_SRC="$SCRIPT_DIR/system_backup.sh"
fi

if [ -f "$SCRIPT_DIR/pishrink.sh" ]; then
    PISHRINK_SRC="$SCRIPT_DIR/pishrink.sh"
fi

# Copy system_backup
if [ -n "$SYSTEM_BACKUP_SRC" ]; then
    cp "$SYSTEM_BACKUP_SRC" "$INSTALL_DIR/system_backup.sh"
    chmod +x "$INSTALL_DIR/system_backup.sh"
    print_success "Installed system_backup.sh"
else
    print_error "system_backup script not found!"
    exit 1
fi

# Copy pishrink
if [ -n "$PISHRINK_SRC" ]; then
    cp "$PISHRINK_SRC" "$INSTALL_DIR/pishrink.sh"
    chmod +x "$INSTALL_DIR/pishrink.sh"
    print_success "Installed pishrink.sh"
else
    print_error "pishrink.sh not found!"
    exit 1
fi

# Step 4: Create symbolic links
print_header "Step 4: Creating Symbolic Links"

# Remove old links if they exist
if [ -L "/usr/local/bin/system_backup" ]; then
    rm /usr/local/bin/system_backup
    print_info "Removed old system_backup link"
fi

if [ -L "/usr/local/bin/pishrink" ]; then
    rm /usr/local/bin/pishrink
    print_info "Removed old pishrink link"
fi

# Create new links
ln -s "$INSTALL_DIR/system_backup.sh" /usr/local/bin/system_backup
print_success "Created /usr/local/bin/system_backup"

ln -s "$INSTALL_DIR/pishrink.sh" /usr/local/bin/pishrink
print_success "Created /usr/local/bin/pishrink"

# Step 5: Verify installation
print_header "Step 5: Verifying Installation"

if command -v system_backup >/dev/null 2>&1; then
    print_success "system_backup command available"
else
    print_error "system_backup command not found!"
    exit 1
fi

if command -v pishrink >/dev/null 2>&1; then
    print_success "pishrink command available"
else
    print_error "pishrink command not found!"
    exit 1
fi

# Step 6: Installation complete
print_header "Installation Complete!"

echo ""
echo "Commands installed:"
echo "  • system_backup - Main backup tool"
echo "  • pishrink - Image size reduction"
echo ""
echo "Quick start:"
echo "  1. Configure your NAS mount (see README.md)"
echo "  2. Run: sudo system_backup /mnt/backup 7"
echo ""
echo "For detailed documentation, see:"
echo "  • README.md - Quick start guide"
echo "  • README.txt - Complete documentation"
echo ""
print_success "Installation successful!"
echo ""

# Optional: Ask about NAS configuration
echo ""
read -p "Would you like help configuring NAS mount now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_header "NAS Configuration Helper"
    
    echo "Select NAS type:"
    echo "  1) NFS"
    echo "  2) SMB/CIFS (Windows share)"
    echo "  3) Skip (configure manually)"
    echo ""
    read -p "Choice (1-3): " nas_choice
    
    case $nas_choice in
        1)
            print_info "NFS Configuration"
            read -p "NAS IP address: " nas_ip
            read -p "NFS share path (e.g., /volume1/backup): " nfs_path
            
            mkdir -p /mnt/backup
            
            echo ""
            print_info "Add this line to /etc/fstab:"
            echo "$nas_ip:$nfs_path /mnt/backup nfs defaults,_netdev 0 0"
            echo ""
            
            read -p "Add to /etc/fstab now? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "$nas_ip:$nfs_path /mnt/backup nfs defaults,_netdev 0 0" >> /etc/fstab
                print_success "Added to /etc/fstab"
                
                print_info "Attempting to mount..."
                if mount -a 2>/dev/null; then
                    if mountpoint -q /mnt/backup; then
                        print_success "NAS mounted successfully!"
                    else
                        print_error "Mount failed - check NAS IP and path"
                    fi
                else
                    print_error "Mount failed - check configuration"
                fi
            fi
            ;;
        2)
            print_info "SMB/CIFS Configuration"
            read -p "NAS IP address: " nas_ip
            read -p "Share name: " share_name
            read -p "Username: " smb_user
            read -s -p "Password: " smb_pass
            echo ""
            
            mkdir -p /mnt/backup
            
            # Create credentials file
            cat > /root/.smbcredentials << EOF
username=$smb_user
password=$smb_pass
EOF
            chmod 600 /root/.smbcredentials
            print_success "Created credentials file"
            
            echo ""
            print_info "Add this line to /etc/fstab:"
            echo "//$nas_ip/$share_name /mnt/backup cifs credentials=/root/.smbcredentials,uid=1000,gid=1000,_netdev 0 0"
            echo ""
            
            read -p "Add to /etc/fstab now? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "//$nas_ip/$share_name /mnt/backup cifs credentials=/root/.smbcredentials,uid=1000,gid=1000,_netdev 0 0" >> /etc/fstab
                print_success "Added to /etc/fstab"
                
                print_info "Installing cifs-utils..."
                apt-get install -y -qq cifs-utils
                
                print_info "Attempting to mount..."
                if mount -a 2>/dev/null; then
                    if mountpoint -q /mnt/backup; then
                        print_success "NAS mounted successfully!"
                    else
                        print_error "Mount failed - check credentials"
                    fi
                else
                    print_error "Mount failed - check configuration"
                fi
            fi
            ;;
        3)
            print_info "Skipping NAS configuration"
            print_info "See README.md for manual configuration instructions"
            ;;
    esac
fi

# Optional: Configure cron
echo ""
read -p "Would you like to schedule automatic backups? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_header "Cron Configuration"
    
    echo "Select backup frequency:"
    echo "  1) Daily at 2:00 AM (keep 7 days)"
    echo "  2) Weekly on Sunday at 3:00 AM (keep 4 weeks)"
    echo "  3) Custom"
    echo "  4) Skip"
    echo ""
    read -p "Choice (1-4): " cron_choice
    
    CRON_LINE=""
    case $cron_choice in
        1)
            CRON_LINE="0 2 * * * /usr/local/bin/system_backup /mnt/backup 7"
            print_info "Daily backup at 2:00 AM, 7 days retention"
            ;;
        2)
            CRON_LINE="0 3 * * 0 /usr/local/bin/system_backup /mnt/backup 28"
            print_info "Weekly backup on Sunday at 3:00 AM, 28 days retention"
            ;;
        3)
            read -p "Enter cron schedule (e.g., 0 2 * * *): " cron_schedule
            read -p "Retention days: " retention
            CRON_LINE="$cron_schedule /usr/local/bin/system_backup /mnt/backup $retention"
            ;;
        4)
            print_info "Skipping cron configuration"
            ;;
    esac
    
    if [ -n "$CRON_LINE" ]; then
        (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
        print_success "Cron job added!"
        echo ""
        print_info "To view scheduled jobs: sudo crontab -l"
    fi
fi

print_header "Setup Complete!"

echo ""
echo "Next steps:"
echo "  1. Test backup: sudo system_backup /mnt/backup 1"
echo "  2. Read documentation: less README.md"
echo "  3. Monitor logs: tail -f /var/log/syslog"
echo ""
print_success "Enjoy your automated backups! 🎉"
echo ""
