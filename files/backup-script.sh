#!/usr/bin/env bash

# Author: Stefan Fluit
# Target: To backup TSM daily
# I wrote a seperate script for this because it is a stripped version of my production script, which includes backup to
# our backup servers. WIll add AWS S3 support later.

declare DefLocation="/var/opt/tableau/tableau_server/data/tabsvc/files/backups/"
declare DateStamp=$(date +"%m_%d_%Y")

# Functions
Configure_Path() {
  source /etc/profile.d/tableau_server.sh
}

# Backup file will automatically be written to '/var/opt/tableau/tableau_server/data/tabsvc/files/backups/backup.tsbak'
backup_tsm() {
  printf "Deleting old local files..\n"
  rm -rf "${DefLocation}"/*.tsbak
  Configure_Path
  tsm maintenance backup --file backup_"${DateStamp}".tsbak
}

main() {
  printf "Starting TSM backup..\n"
  backup_tsm
  printf "Done with TSM backup..\n"
}

main
