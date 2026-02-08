# 🔥 Raspberry PI HOT Backup Script

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-Compatible-C51A4A.svg)](https://www.raspberrypi.org/)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-89E051.svg)](https://www.gnu.org/software/bash/)

Sistema completo e automatico per creare backup della scheda SD del Raspberry Pi con riduzione automatica delle dimensioni e gestione intelligente della retention.

> 🔗 **Basato su**: [BASH-RaspberryPI-System-Backup](https://github.com/kallsbo/BASH-RaspberryPI-System-Backup) di Kristofer Källsbo

## ✨ Caratteristiche Principali

- 🔥 **Backup "a caldo"** - Crea backup mentre il sistema è in esecuzione, senza interruzioni
- 📦 **Riduzione automatica** - Passa da ~16GB a ~3-4GB con pishrink
- 🔄 **Auto-espansione** - Ripristina su SD di qualsiasi dimensione, espansione automatica al primo boot
- 🗂️ **Gestione retention** - Cancellazione automatica dei backup vecchi
- 🛡️ **Controlli di sicurezza** - Verifica mount point, spazio disco, integrità backup
- ⏰ **Automazione cron** - Pianifica backup giornalieri, settimanali o mensili
- 📊 **Supporto multi-destinazione** - NAS (NFS/SMB), USB, disco locale
- 📏 **Verifica spazio** - Confronta dimensione SD con spazio disponibile

## 🎯 Auto-Espansione

> **⭐ Passa facilmente a SD card più grandi (o più piccole) senza configurazione manuale!**

Quando ripristini un backup ridotto, il sistema si **espande automaticamente** al primo boot per utilizzare tutto lo spazio disponibile sulla SD.

### Esempio Pratico

```
┌─────────────────────────────────────────────────────────────┐
│ Backup di SD 16GB → Ridotto a 3.5GB                         │
│ Ripristino su SD 64GB → Espansione automatica a 64GB        │
└─────────────────────────────────────────────────────────────┘
```
```
┌─────────────────────────────────────────────────────────────┐
│ Backup di SD 16GB → Ridotto a 3.5GB                         │
│ Ripristino su SD 8GB → Espansione automatica a 8GB          │
└─────────────────────────────────────────────────────────────┘
```

**Nessun comando da digitare. Nessuna configurazione. Completamente automatico.**

## 📋 Indice

- [Requisiti](#-requisiti)
- [Installazione Rapida](#-installazione-rapida)
- [Utilizzo Base](#-utilizzo-base)
- [Configurazione NAS](#-configurazione-nas)
- [Automazione con Cron](#-automazione-con-cron)
- [Esempi Pratici](#-esempi-pratici)
- [FAQ](#-faq)
- [Risoluzione Problemi](#-risoluzione-problemi)
- [Licenza](#-licenza)

## 🔧 Requisiti

### Hardware
- Raspberry Pi (tutti i modelli)
- Destinazione backup: NAS di rete, disco USB, o disco locale
- Spazio disponibile: minimo 2x dimensione SD card

### Software
- Raspberry Pi OS (o altra distribuzione Debian-based)
- Privilegi root (sudo)
- Pacchetti richiesti (installazione automatica):
  ```bash
  parted e2fsprogs
  ```

## 🚀 Installazione Rapida

### Metodo 1: Da GitHub (Raccomandato)

```bash
# 1. Clona il repository
git clone https://github.com/flanesi/Raspberry-PI-HOT-Backup-script.git
cd Raspberry-PI-HOT-Backup-script

# 2. Esegui lo script di installazione
sudo bash install.sh

# 3. Verifica installazione
system_backup --help
```

### Metodo 2: Download Manuale

```bash
# 1. Scarica l'archivio
wget https://github.com/flanesi/Raspberry-PI-HOT-Backup-script/archive/main.zip
unzip main.zip
cd Raspberry-PI-HOT-Backup-script-main

# 2. Installa
sudo bash install.sh
```

### Metodo 3: Installazione Manuale Passo-Passo

```bash
# 1. Installa dipendenze
sudo apt-get update
sudo apt-get install -y parted e2fsprogs

# 2. Crea directory e copia script
sudo mkdir -p /var/www/MyScripts
sudo cp system_backup.sh /var/www/MyScripts/system_backup.sh
sudo cp pishrink.sh /var/www/MyScripts/pishrink.sh
sudo chmod +x /var/www/MyScripts/*.sh

# 3. Crea link simbolici
sudo ln -s /var/www/MyScripts/system_backup.sh /usr/local/bin/system_backup
sudo ln -s /var/www/MyScripts/pishrink.sh /usr/local/bin/pishrink

# 4. Verifica
which system_backup
which pishrink
```

## 💡 Utilizzo Base

### Sintassi

```bash
sudo system_backup [percorso_backup] [giorni_retention]
```

### Esempi

```bash
# Usa valori di default (/mnt/backup, 3 giorni)
sudo system_backup

# Specifica percorso
sudo system_backup /mnt/nas-backup

# Specifica percorso e retention
sudo system_backup /mnt/backup 7

# Backup settimanale con retention lunga
sudo system_backup /mnt/backup 28
```

### Cosa Succede Durante l'Esecuzione

```
[INFO] Raspberry Pi System Backup Starting
[INFO] Configuration:
[INFO]   Hostname: raspberry-pi
[INFO]   SD card size: 16GB
[INFO]   Space required: 16GB (minimum)
[INFO]   Space recommended: 32GB (for retention)
[INFO]   Backup path: /mnt/backup
[INFO]   Retention: 7 days

[INFO] Testing write access...           ✓
[INFO] Testing mount responsiveness...   ✓
[INFO] Found 2 existing backup(s)

[INFO] Checking available disk space...
[INFO] SD card size: 16GB
[INFO] Destination available space: 120GB
[INFO] Space check OK: 120GB available (32GB recommended)

[INFO] Creating Backup
[INFO] Starting dd operation...
15728640000 bytes (16 GB) copied, 580 s, 27.1 MB/s
[INFO] dd completed in 9m 40s

[INFO] Resizing Image
[INFO] Original size: 15G
[INFO] New size: 3.1G                    ✓

[INFO] Backup completed successfully!
```

## 🌐 Configurazione NAS

### Preparazione NAS

Prima di eseguire i backup, è necessario configurare una cartella condivisa sul NAS e montarla sul Raspberry Pi.

### Opzione A: NFS

**Sul NAS:**
- Crea una cartella condivisa (es. `/volume1/pi-backup`)
- Configura permessi NFS per permettere l'accesso dal Raspberry Pi
- Annota l'indirizzo IP del NAS

**Sul Raspberry Pi:**
- Installa il client NFS: `sudo apt-get install nfs-common`
- Crea punto di mount: `sudo mkdir -p /mnt/backup`
- Configura il mount in `/etc/fstab` per renderlo permanente
- Verifica il mount con: `mountpoint /mnt/backup`

### Opzione B: SMB/CIFS (Windows Share)

**Sul NAS:**
- Crea una cartella condivisa SMB/CIFS (es. `pi-backup`)
- Configura username e password per l'accesso
- Annota l'indirizzo IP del NAS e il nome della condivisione

**Sul Raspberry Pi:**
- Installa il client CIFS: `sudo apt-get install cifs-utils`
- Crea punto di mount: `sudo mkdir -p /mnt/backup`
- Crea file credenziali in `/root/.smbcredentials` (protetto)
- Configura il mount in `/etc/fstab`
- Verifica il mount con: `mountpoint /mnt/backup`

### Opzione C: Disco USB

**Preparazione:**
- Collega il disco USB al Raspberry Pi
- Identifica il device (es. `/dev/sda1`)
- Crea punto di mount: `sudo mkdir -p /mnt/backup`
- Monta il disco e configura mount automatico in `/etc/fstab`

### Verifica Configurazione

Dopo aver configurato il mount:
```bash
# Il mount deve essere attivo
mountpoint -q /mnt/backup && echo "✓ OK" || echo "✗ ERRORE"

# Deve essere scrivibile
sudo touch /mnt/backup/test.txt && sudo rm /mnt/backup/test.txt

# Verifica spazio disponibile
df -h /mnt/backup
```

> 💡 **Nota**: Per istruzioni dettagliate sui comandi di mount, consulta il file [manual.txt](manual.txt)

## ⏰ Automazione con Cron

### Configurazione Base

```bash
# Apri crontab
sudo crontab -e
```

### Esempi di Configurazione

```bash
# Backup giornaliero alle 2:00 AM, mantieni 7 giorni
0 2 * * * /usr/local/bin/system_backup /mnt/backup 7

# Backup settimanale (domenica) alle 3:00 AM, mantieni 4 settimane
0 3 * * 0 /usr/local/bin/system_backup /mnt/backup 28

# Backup mensile (primo giorno del mese), mantieni 6 mesi
0 4 1 * * /usr/local/bin/system_backup /mnt/backup 180
```

## 📚 Esempi Pratici

### Scenario 1: Prima Configurazione Completa

```bash
# Setup completo da zero con backup giornaliero

# 1. Installa sistema
git clone https://github.com/flanesi/Raspberry-PI-HOT-Backup-script.git
cd Raspberry-PI-HOT-Backup-script
sudo bash install.sh

# 2. Configura mount NAS (vedi sezione Configurazione NAS)

# 3. Test backup
sudo system_backup /mnt/backup 7

# 4. Automatizza
echo "0 2 * * * /usr/local/bin/system_backup /mnt/backup 7" | sudo crontab -
```

### Scenario 2: Upgrade a SD Più Grande

```bash
# Passare da SD 16GB a 32GB

# 1. Crea backup
sudo system_backup /mnt/backup 1

# 2. Spegni Pi
sudo shutdown -h now

# 3. Su PC: scrivi backup su nuova SD 32GB con Raspberry Pi Imager

# 4. Inserisci nuova SD e avvia
# ⭐ Al primo boot: espansione automatica a 32GB!

# 5. Verifica spazio
df -h /
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/root        30G  3.5G   25G  13% /
```

### Scenario 3: Ripristino Dopo Disastro

```bash
# SD card si rompe - ripristino da backup

# 1. Identifica ultimo backup valido

# 2. Su PC: scrivi backup su nuova SD con Raspberry Pi Imager

# 3. Inserisci SD e avvia
# Sistema ripristinato allo stato del backup! ✓
```

## ❓ FAQ

### Posso usare il Raspberry Pi durante il backup?

**Sì!** Il backup è "a caldo" - il sistema continua a funzionare normalmente. Evita solo di spegnere il dispositivo durante il backup.

### Il backup include tutti i file?

**Sì**, è una copia bit-per-bit completa della SD card. Include sistema operativo, configurazioni, applicazioni, dati utente - tutto.

### Come funziona l'auto-espansione?

Quando ripristini un backup ridotto su una SD più grande:

1. **Primo boot**: Il sistema rileva la dimensione reale della SD
2. **Espansione automatica**: La partizione si espande per usare tutto lo spazio
3. **Riavvio automatico**: Il sistema si riavvia
4. **Secondo boot**: Sistema pronto con tutta la SD disponibile

**Nessun comando manuale richiesto!**

### Quanto tempo richiede un backup?

- **Creazione (dd)**: 10-15 minuti per SD 16GB
- **Riduzione (pishrink)**: 3-5 minuti
- **Totale**: ~15-20 minuti

### Quanto spazio occupa un backup?

- **Senza pishrink**: ~16GB (dimensione SD)
- **Con pishrink**: ~3-4GB (60-80% di risparmio)
- **Con retention 7 giorni**: ~28GB totali (7 × 4GB)

### Posso ripristinare su SD di dimensione diversa?

**Sì!** Puoi ripristinare:
- ✅ Su SD **più grande** (auto-espansione automatica)
- ✅ Su SD **più piccola** (se immagine ridotta < nuova SD)
- ✅ Su SD **identica** (espansione automatica alle dimensioni originali)

### Come ripristino un backup?

**Metodo 1: Raspberry Pi Imager (Raccomandato)**
1. Apri Raspberry Pi Imager
2. Choose OS → Use custom
3. Seleziona file .img
4. Choose Storage → seleziona SD
5. Write

**Metodo 2: Linux/Mac Terminal**
```bash
sudo dd if=backup.img of=/dev/sdX bs=4M status=progress
sync
```

### Il backup funziona via WiFi?

**Sì**, ma è più lento. Raccomandato Ethernet cablato per velocità ottimale.

## 🔧 Risoluzione Problemi

### Errore: "NOT a mount point"

**Causa**: Il NAS non è montato

**Soluzione**:
```bash
# Verifica mount
mount | grep backup

# Rimonta
sudo mount -a

# Controlla /etc/fstab
cat /etc/fstab | grep backup
```

### Errore: "Permission denied"

**Causa**: Permessi insufficienti o credenziali errate

**Soluzione**:
```bash
# Usa sudo
sudo system_backup

# Verifica permessi NAS
ls -ld /mnt/backup

# Test scrittura
sudo touch /mnt/backup/test && sudo rm /mnt/backup/test
```

### Errore: "No space left on device"

**Causa**: NAS pieno

**Soluzione**:
```bash
# Verifica spazio
df -h /mnt/backup

# Cancella backup vecchi manualmente
ls -lt /mnt/backup/*.img | tail -3
sudo rm /mnt/backup/vecchio.img

# Riduci retention
sudo system_backup /mnt/backup 3
```

### Backup molto lento

**Soluzioni**:
- Usa Ethernet invece di WiFi
- Verifica velocità NAS
- Normale: 10-15 min per 16GB è OK
- Se >30 min, controlla connessione di rete

### Cron non esegue backup

**Soluzioni**:
```bash
# Verifica cron attivo
sudo systemctl status cron

# Controlla sintassi
sudo crontab -l

# Verifica log
grep CRON /var/log/syslog

# Test manuale
sudo /usr/local/bin/system_backup /mnt/backup 7
```

## 📖 Documentazione Completa

Per la documentazione completa e dettagliata, consulta [manual.txt](manual.txt).

Include:
- Spiegazione tecnica dettagliata di ogni componente
- Configurazioni avanzate
- Scenari complessi
- Best practices professionali
- Debugging avanzato

## 📝 Licenza

Questo progetto è rilasciato sotto licenza MIT. Vedi il file [LICENSE](LICENSE) per i dettagli.

## 🙏 Riconoscimenti

- **Kristofer Källsbo** - Per il [sistema di backup originale](https://github.com/kallsbo/BASH-RaspberryPI-System-Backup)
- **Drew Bonasera (Drewsif)** - Per [PiShrink](https://github.com/Drewsif/PiShrink)
- **Community Raspberry Pi** - Per supporto e feedback

## 🌟 Progetti Correlati

- [BASH-RaspberryPI-System-Backup](https://github.com/kallsbo/BASH-RaspberryPI-System-Backup) - Script originale di Kristofer Källsbo
- [PiShrink](https://github.com/Drewsif/PiShrink) - Script originale per riduzione immagini
- [Raspberry Pi Imager](https://www.raspberrypi.org/software/) - Tool ufficiale per scrivere immagini
- [Win32DiskImager](https://win32diskimager.org/) - Tool per Windows per scrivere immagini su SD

---

<div align="center">

**Se questo progetto ti è stato utile, lascia una ⭐ su GitHub!**

Made with ❤️ for the Raspberry Pi Community

[Torna su ⬆️](#-raspberry-pi-hot-backup-script)

</div>
