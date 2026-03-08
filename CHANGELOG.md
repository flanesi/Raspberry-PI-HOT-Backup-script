# Changelog

All notable changes to Raspberry PI HOT Backup Script will be documented in this file.

## [1.0.2] - 2026-03-08

### Changed
- **Retention logic**: Changed from time-based (days) to **count-based** retention. The second parameter now specifies how many recent backups to keep, regardless of their age. For example, `retention_count=3` always keeps the 3 most recent backups and deletes any older ones.
- Renamed internal variable `retention_days` → `retention_count` for clarity
- Updated all log messages to reflect count-based retention policy
- Updated `--help` output and header comments to document the new behaviour

### Migration note
If you had cron jobs using the old day-based parameter (e.g. `system_backup /mnt/backup 7` meaning "7 days"), the number you pass now means "keep last N backups". For daily backups the number stays the same conceptually; just be aware the semantics have changed.

## [1.0.1] - 2026-03-07

### Added
- **Progress bar with ETA**: Added support for `pv` (Pipe Viewer) to display estimated time remaining during backup
- **Help command**: Added `--help` flag to display usage guide
- **Version command**: Added `--version` flag to display script version
- SD card size detection now shown in initial configuration output
- Space requirement information displayed at startup
- Automatic `pv` installation in install.sh (optional package)
- Comprehensive documentation for ETA feature

### Changed
- Improved backup progress display with real-time ETA when `pv` is available
- Enhanced user experience with visual progress bar and percentage
- Fallback to standard `dd` progress if `pv` is not installed

### Documentation
- Updated README.md with new progress output example and help commands
- Updated manual.txt with pv installation, usage instructions, and help commands
- Added ETA_FEATURE.txt with complete documentation

## [1.0.0] - 2025-02-08

### Added
- Initial release of Raspberry PI HOT Backup Script
- Hot backup support (backup while system is running)
- Automatic SD card size verification
- Space availability check before backup
- Automatic image size reduction with pishrink
- Intelligent retention management
- Multiple safety checks (mount point, write access, space verification)
- Support for NAS (NFS/SMB), USB, and local disk destinations
- Comprehensive documentation (README.md and manual.txt)
- Automatic installation script with wizard
- GitHub publication ready package

### Features
- Backup creation with dd
- Automatic resize with pishrink (60-80% space savings)
- Auto-expansion on restore to any SD card size
- Retention-based old backup deletion
- Cron automation support
- Extensive error handling and logging

---

## Version History

- **v1.0.2** (2026-03-08) - Count-based retention (keep last N backups instead of N days)
- **v1.0.1** (2026-03-07) - Added ETA support with pv, --help and --version commands
- **v1.0.0** (2025-02-08) - Initial stable release
