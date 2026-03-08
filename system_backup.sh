#!/bin/bash
#
# =====================================================
# Raspberry Pi System Backup Script - Production Version
# =====================================================
#
# Automates full SD card backup with safety checks and intelligent retention
#
# AUTHOR: Based on Kristofer Källsbo's work, enhanced by Flavio Anesi
# VERSION: 1.0.2
# DATE: March 8, 2026
#
# =====================================================
# SYNTAX
# =====================================================
#
# system_backup.sh [backup_path] [retention_count]
#
# PARAMETERS:
#   backup_path      Path where backups will be saved (must be a mount point)
#                    Default: /mnt/backup
#
#   retention_count  Number of most recent backups to keep
#                    Older backups beyond this count will be deleted
#                    Default: 3
#
# =====================================================
# DEFAULT VALUES
# =====================================================
#
# backup_path      = /mnt/backup
# retention_count  = 3 (keep the 3 most recent backups)
# resize           = 1 (enabled - uses pishrink to reduce image size)
#
# =====================================================
# USAGE EXAMPLES
# =====================================================
#
# 1. Use all defaults (backup to /mnt/backup, keep 3 most recent)
#    sudo system_backup.sh
#
# 2. Specify backup path only (use default 3 backups retention)
#    sudo system_backup.sh /mnt/nas-backup
#
# 3. Specify both path and retention count
#    sudo system_backup.sh /mnt/backup 7
#
# 4. Weekly backup keeping last 4
#    sudo system_backup.sh /mnt/weekly-backup 4
#
# 5. Daily backup to USB drive, keep last 7
#    sudo system_backup.sh /media/usb-disk 7
#
# =====================================================
# CRON EXAMPLES
# =====================================================
#
# Daily backup at 2:00 AM, keep last 7 backups:
#   0 2 * * * /usr/local/bin/system_backup /mnt/backup 7 >> /var/log/backup_cron.log 2>&1
#
# Weekly backup on Sunday at 3:00 AM, keep last 4 backups:
#   0 3 * * 0 /usr/local/bin/system_backup /mnt/backup 4 >> /var/log/backup_cron.log 2>&1
#
# =====================================================
# INSTALLATION
# =====================================================
#
# 1. Copy script to system location:
#    sudo cp system_backup.sh /var/www/MyScripts/system_backup.sh
#    sudo chmod +x /var/www/MyScripts/system_backup.sh
#
# 2. Create symbolic link:
#    sudo ln -s /var/www/MyScripts/system_backup.sh /usr/local/bin/system_backup
#
# 3. Verify installation:
#    which system_backup
#
# =====================================================
# REQUIREMENTS
# =====================================================
#
# - Root privileges (run with sudo)
# - Backup destination must be a mounted filesystem (NAS, USB, etc.)
# - Required tools: dd, find, stat, sync, parted, losetup
# - Optional: pishrink (for image compression, highly recommended)
#
# =====================================================
# SAFETY FEATURES
# =====================================================
#
# - Verifies backup destination is a valid mount point
# - Checks available disk space
# - Validates backup file size before deleting old backups
# - Uses safe find commands with -maxdepth to prevent accidents
#
# =====================================================
# OUTPUT
# =====================================================
#
# Backup files are named: HOSTNAME.YYYYmmdd_HHMMSS.img
# Example: raspberry-pi.20250208_020015.img
#
# =====================================================

set -u  # Exit on undefined variables
set -o pipefail  # Exit on pipe failures

# =====================================================
# CONFIGURATION
# =====================================================
backup_path=/mnt/backup
retention_count=3
resize=1
MIN_EXPECTED_BACKUPS=0  # Minimo numero di backup che devono esistere (0 per il primo backup)

# =====================================================
# FUNCTIONS
# =====================================================
show_help() {
    cat << EOF
Raspberry Pi System Backup Script v1.0.2

USAGE:
    sudo system_backup [BACKUP_PATH] [RETENTION_COUNT]

DESCRIPTION:
    Creates a complete backup of the Raspberry Pi SD card while the system
    is running (HOT backup). Automatically reduces image size with pishrink
    and manages old backups based on retention policy.

PARAMETERS:
    BACKUP_PATH       Directory where backups will be saved (must be mounted)
                      Default: /mnt/backup
                      Example: /mnt/nas-backup, /media/usb-backup

    RETENTION_COUNT   Number of most recent backups to keep.
                      Backups beyond this count will be deleted automatically,
                      regardless of their age.
                      Default: 3
                      Recommended: 7 (keep last 7 backups)

EXAMPLES:
    # Use default settings (backup to /mnt/backup, keep last 3 backups)
    sudo system_backup

    # Backup to custom location keeping last 7 backups
    sudo system_backup /mnt/nas-backup 7

    # Backup to USB drive keeping last 14 backups
    sudo system_backup /media/usb-backup 14

    # Weekly backup keeping last 4 backups
    sudo system_backup /mnt/weekly-backup 4

FEATURES:
    • HOT backup - No need to shutdown the system
    • Automatic SD card size detection
    • Space verification before backup
    • Progress bar with ETA (if pv is installed)
    • Automatic image reduction with pishrink (60-80% savings)
    • Auto-expansion on restore to any SD card size
    • Intelligent retention management
    • Multiple safety checks

REQUIREMENTS:
    • Root privileges (sudo)
    • Mount point for backup destination
    • Free space >= SD card size
    • Optional: pv (for progress bar with ETA)

SPACE REQUIREMENTS:
    Without pishrink:  SD card size × retention count
    With pishrink:     ~4GB × retention count (for 16GB SD)
    
    Example for 16GB SD, keeping 7 backups:
    • Without resize: ~112GB (16GB × 7)
    • With resize:    ~28GB (4GB × 7)

OUTPUT FILES:
    Backups are saved with format: HOSTNAME.YYYYmmdd_HHMMSS.img
    Example: raspberry-pi.20250302_143022.img

INSTALLATION:
    sudo apt-get install pv  # Optional, for ETA display
    
MORE INFO:
    Documentation:  See manual.txt for complete guide
    Repository:     https://github.com/flanesi/Raspberry-PI-HOT-Backup-script
    Version:        1.0.2
    Author:         Based on Kristofer Källsbo's work, enhanced by Flavio Anesi

EOF
    exit 0
}

show_version() {
    echo "Raspberry Pi System Backup Script v1.0.2"
    echo "March 8, 2026"
    echo ""
    echo "Based on: Kristofer Källsbo's BASH-RaspberryPI-System-Backup"
    echo "Enhanced by: Flavio Anesi"
    echo "License: MIT"
    exit 0
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${CYAN}[INFO $(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR $(date '+%Y-%m-%d %H:%M:%S')] $*${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING $(date '+%Y-%m-%d %H:%M:%S')] $*${NC}"
}

log_section() {
    echo -e ""
    echo -e "${BOLD}${GREEN}==========================================${NC}"
    echo -e "${BOLD}${GREEN}  $*${NC}"
    echo -e "${BOLD}${GREEN}==========================================${NC}"
    echo -e ""
}

log_success() {
    echo -e "${CYAN}[INFO $(date '+%Y-%m-%d %H:%M:%S')]${NC} ${GREEN}✓${NC} $*"
}

log_fail() {
    echo -e "${CYAN}[INFO $(date '+%Y-%m-%d %H:%M:%S')]${NC} ${RED}✗${NC} $*"
}

cleanup_on_error() {
    log_error "Script failed, performing cleanup..."
    rm -f /boot/forcefsck
    exit 1
}

trap cleanup_on_error ERR

# =====================================================
# ARGUMENT PARSING
# =====================================================

# Check for help or version flags
case "${1:-}" in
    -h|--help|help)
        show_help
        ;;
    -v|--version|version)
        show_version
        ;;
esac

if [ ! -z "${1:-}" ]; then
    backup_path="$1"
fi

if [ ! -z "${2:-}" ]; then
    retention_count="$2"
fi

# =====================================================
# PRE-FLIGHT CHECKS
# =====================================================
log_section "Raspberry Pi System Backup Starting"

# Check 1: Root privileges
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root!"
    log_error "Use: sudo $0"
    exit 1
fi

# Check 2: Set and verify hostname
if [ -z "${HOSTNAME:-}" ]; then
    HOSTNAME=$(hostname)
    log_warning "HOSTNAME was not set, using: $HOSTNAME"
fi

if [ -z "$HOSTNAME" ]; then
    log_error "Unable to determine hostname!"
    exit 1
fi

log_info "Configuration:"
log_info "  Hostname: $HOSTNAME"
log_info "  Backup path: $backup_path"
log_info "  Retention: keep last $retention_count backup(s)"
log_info "  Resize enabled: $resize"

# Check 3: Verify backup path exists
if [ ! -d "$backup_path" ]; then
    log_error "Backup path '$backup_path' does not exist!"
    exit 1
fi

# Check 4: Verify it's a mount point
if ! mountpoint -q "$backup_path" 2>/dev/null; then
    log_error "CRITICAL: '$backup_path' is NOT a mount point!"
    log_error "This could indicate the NAS is not mounted."
    log_error "Please verify with: mount | grep backup"
    exit 1
fi

# Check 5: Verify mount is read/write
log_info "Testing write access to backup path..."
test_file="$backup_path/.backup_write_test_$$"
if ! touch "$test_file" 2>/dev/null; then
    log_error "Cannot write to '$backup_path'!"
    log_error "Mount might be read-only or insufficient permissions."
    exit 1
fi
rm -f "$test_file"

# Check 6: Verify network mount is responsive
log_info "Testing mount responsiveness..."
if ! timeout 10 ls -la "$backup_path" > /dev/null 2>&1; then
    log_error "Backup path is not responsive (possible network issue)"
    exit 1
fi

# Check 7: List existing backups
log_info "Scanning for existing backups..."
existing_backups=$(find "$backup_path" -maxdepth 1 -name "$HOSTNAME.*.img*" -type f 2>/dev/null)
existing_count=$(echo "$existing_backups" | grep -c "^" 2>/dev/null || echo 0)

if [ -n "$existing_backups" ]; then
    log_info "Found $existing_count existing backup(s):"
    echo "$existing_backups" | while read -r file; do
        if [ -f "$file" ]; then
            log_info "  - $(basename "$file") ($(ls -lh "$file" | awk '{print $5}'))"
        fi
    done
else
    log_info "No existing backups found (this might be the first backup)"
fi

# Check 8: Verify minimum backups (if configured)
if [ $existing_count -lt $MIN_EXPECTED_BACKUPS ]; then
    log_warning "Expected at least $MIN_EXPECTED_BACKUPS backup(s), found $existing_count"
    log_warning "Continuing anyway..."
fi

# Check 9: Disk space check
log_info "Checking available disk space..."

# Get SD card size
if [ -b "/dev/mmcblk0" ]; then
    sd_size_bytes=$(blockdev --getsize64 /dev/mmcblk0 2>/dev/null || echo 0)
    sd_size_gb=$((sd_size_bytes / 1024 / 1024 / 1024))
    log_info "SD card size: ${sd_size_gb}GB"
else
    log_warning "Cannot detect SD card size, assuming 16GB"
    sd_size_gb=16
fi

# Get available space on destination
available_kb=$(df "$backup_path" | awk 'NR==2 {print $4}')
available_gb=$((available_kb / 1024 / 1024))

log_info "Destination available space: ${available_gb}GB"

# Verify destination has enough space for full SD backup
if [ $available_gb -lt $sd_size_gb ]; then
    log_error "Not enough space on destination!"
    log_error "SD card: ${sd_size_gb}GB, Available: ${available_gb}GB"
    log_error "Need at least ${sd_size_gb}GB free space"
    exit 1
fi

# Warn if space is tight (less than 2x SD size for safety)
recommended_gb=$((sd_size_gb * 2))
if [ $available_gb -lt $recommended_gb ]; then
    log_warning "Limited space! Available: ${available_gb}GB"
    log_warning "Recommended: ${recommended_gb}GB (2x SD size) for multiple backups"
    log_warning "Continuing, but consider freeing up space or reducing retention"
else
    log_info "Space check OK: ${available_gb}GB available (${recommended_gb}GB recommended)"
fi

# Check 10: Verify required tools
log_info "Verifying required tools..."
for tool in dd sync find stat; do
    if ! command -v $tool >/dev/null 2>&1; then
        log_error "Required tool '$tool' not found!"
        exit 1
    fi
done

if [ $resize -eq 1 ]; then
    if ! command -v pishrink >/dev/null 2>&1; then
        log_warning "pishrink not found, resize will be skipped"
        resize=0
    fi
fi

# =====================================================
# BACKUP CREATION
# =====================================================
log_info ""
log_section "Creating Backup"

# Create fsck trigger
touch /boot/forcefsck

# Generate backup filename
backup_date=$(date +%Y%m%d_%H%M%S)
backup_file="$backup_path/$HOSTNAME.$backup_date.img"

log_info "Backup file: $backup_file"
log_info "Source: /dev/mmcblk0"

start_time=$(date +%s)

# Check if pv is available for better progress display with ETA
if command -v pv >/dev/null 2>&1; then
    log_info "Starting backup with progress bar (ETA displayed)..."
    # Use pv to show progress bar with ETA, speed, and percentage
    # -s = size for percentage calculation
    # -p = percentage
    # -t = elapsed time  
    # -e = ETA (estimated time remaining)
    # -r = rate (speed)
    # -a = average rate
    # -b = bytes transferred
    if ! dd if=/dev/mmcblk0 bs=1M 2>/dev/null | pv -s "$sd_size_bytes" -p -t -e -r -a -b | dd of="$backup_file" bs=1M conv=fsync 2>/dev/null; then
        log_error "Backup failed!"
        rm -f /boot/forcefsck
        rm -f "$backup_file"
        exit 1
    fi
else
    log_info "Starting dd operation (this will take several minutes)..."
    log_info "Install 'pv' for progress bar with ETA: sudo apt-get install pv"
    # Fallback to standard dd with status=progress
    if ! dd if=/dev/mmcblk0 of="$backup_file" bs=1M conv=fsync status=progress 2>&1; then
        log_error "dd command failed!"
        rm -f /boot/forcefsck
        rm -f "$backup_file"
        exit 1
    fi
fi

end_time=$(date +%s)
duration=$((end_time - start_time))
duration_min=$((duration / 60))
duration_sec=$((duration % 60))
log_info "Backup completed in ${duration_min}m ${duration_sec}s"

# Remove fsck trigger
rm -f /boot/forcefsck

# =====================================================
# BACKUP VERIFICATION
# =====================================================
log_info ""
log_info "Verifying backup integrity..."

# Check file exists
if [ ! -f "$backup_file" ]; then
    log_error "Backup file was not created!"
    exit 1
fi

# Check file size
backup_size=$(stat -c%s "$backup_file" 2>/dev/null)
backup_size_mb=$((backup_size / 1024 / 1024))
min_expected_mb=500  # Minimum 500MB for a valid Raspberry Pi image

log_info "Backup size: ${backup_size_mb}MB"

if [ $backup_size -lt $((min_expected_mb * 1024 * 1024)) ]; then
    log_error "Backup file is suspiciously small (${backup_size_mb}MB < ${min_expected_mb}MB)"
    log_error "Backup might be corrupted. NOT deleting old backups!"
    exit 1
fi

# Force sync
log_info "Syncing filesystem..."
sync
sleep 2

log_info "Backup created successfully: $(ls -lh "$backup_file" | awk '{print $5}')"

# =====================================================
# OLD BACKUP DELETION
# =====================================================
log_info ""
log_section "Checking Old Backups"

log_info "Retention policy: keep last $retention_count backup(s)"

# List all backups sorted by modification time, newest first
all_backups=$(find "$backup_path" -maxdepth 1 -name "$HOSTNAME.*.img*" -type f 2>/dev/null \
    | xargs ls -t 2>/dev/null || echo "")

total_count=$(echo "$all_backups" | grep -c "^" 2>/dev/null || echo 0)
log_info "Total backups currently on disk: $total_count"

if [ $total_count -le $retention_count ]; then
    log_info "No old backups to delete (have $total_count, limit is $retention_count)."
else
    # Backups to delete = all lines after the first $retention_count
    old_backups=$(echo "$all_backups" | tail -n +$((retention_count + 1)))
    delete_count=$(echo "$old_backups" | grep -c "^" 2>/dev/null || echo 0)

    log_info "Found $delete_count backup(s) to delete (keeping newest $retention_count):"
    echo "$old_backups" | while read -r file; do
        if [ -f "$file" ]; then
            log_info "  - $(basename "$file") ($(ls -lh "$file" | awk '{print $5}'))"
        fi
    done

    # Safety check: we must always keep at least 1 backup
    remaining=$((total_count - delete_count))
    if [ $remaining -lt 1 ]; then
        log_warning "SAFETY ABORT: Deletion would leave 0 backups!"
        log_warning "Keeping old backups for safety."
    else
        log_info "After deletion, there will be $remaining backup(s) remaining."
        log_info "Proceeding with deletion..."

        echo "$old_backups" | while read -r file; do
            if [ -f "$file" ]; then
                log_info "Deleting: $(basename "$file")"
                if rm -f "$file"; then
                    log_success "Deleted successfully"
                else
                    log_fail "Failed to delete"
                fi
            fi
        done

        log_info "Old backup deletion completed."
    fi
fi

# =====================================================
# IMAGE RESIZE
# =====================================================
if [ $resize -eq 1 ]; then
    log_section "Resizing Image"
    
    original_size=$(ls -lh "$backup_file" | awk '{print $5}')
    log_info "Original size: $original_size"
    log_info "Running pishrink (this may take a while)..."
    
    if pishrink -v "$backup_file" 2>&1; then
        new_size=$(ls -lh "$backup_file" | awk '{print $5}')
        log_info "Resize successful!"
        log_info "New size: $new_size"
    else
        log_warning "pishrink failed, but backup is still valid at original size"
    fi
fi

# =====================================================
# FINAL SUMMARY
# =====================================================
log_info ""
log_section "Backup Summary"

final_backups=$(find "$backup_path" -maxdepth 1 -name "$HOSTNAME.*.img*" -type f 2>/dev/null)
final_count=$(echo "$final_backups" | grep -c "^" 2>/dev/null || echo 0)

log_info "Total backups on NAS: $final_count"

if [ -n "$final_backups" ]; then
    echo "$final_backups" | while read -r file; do
        if [ -f "$file" ]; then
            file_date=$(stat -c %y "$file" | cut -d' ' -f1)
            log_info "  - $(basename "$file") ($(ls -lh "$file" | awk '{print $5}'), created: $file_date)"
        fi
    done
fi

log_info ""
log_success "Backup completed successfully at $(date)"

exit 0
