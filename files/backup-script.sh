#!/usr/bin/env bash

# Author: Stefan Fluit
# Target: To backup TSM daily.

# Variables
declare TSM_BIN="/opt/tableau/tableau_server/packages/customer-bin"
declare DefLocation="/var/opt/tableau/tableau_server/data/tabsvc/files/backups/"
declare DateStamp=$(date +"%m_%d_%Y")
declare Files01User="root"
declare Files01IP="172.17.2.10"
declare BackupLocation="/mnt/bigstorage2/tableau_linux"
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:${TSM_BIN}

# Functions
Configure_Path() {
  source /etc/profile.d/tableau_server.sh
}

# Backup file will automatically be written to '/var/opt/tableau/tableau_server/data/tabsvc/files/backups/backup<DateStamp>.tsbak'
backup_tsm() {
    printf "Deleting old local files..\n"
    Configure_Path
    tsm maintenance backup --file backup_"${DateStamp}".tsbak
}

count_backups() {
  local -i count=$("ls -al ${BackupLocation} | wc -l")
    if [[ "${count}" -gt 15  ]]
    then
      "ls -A1t ${BackupLocation} | tail -n +11 | xargs rm"
    else
      printf "Retention not exceeded, yet."
    fi
}

main() {
    printf "Starting TSM backup script..\n" && backup_tsm
    printf "Done with TSM backup..\n"
    printf "Starting cleanup of old backups..\n"
    count_backups && printf "\nDone cleaning. Bye!\n"
}

main
