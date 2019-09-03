#!/usr/bin/env bash

# Author: Stefan Fluit
# Target: Run after setup scripts to initialze TSM services manager and prepare for finalizing.
# Run this script as TSM_Admin, without sudo.

# Set Bash behaviour
set -o errexit      #Exit on uncaught errors
set -o pipefail 	#Fail pipe on first error

# Variables
declare registration_file="/tmp/tableau-transip/files/tableau-init-files/registration_file.json"
declare init_settings_file="/tmp/tableau-transip/files/tableau-init-files/init_settings.json"
declare tsm_version="20192.19.0718.1543"
declare license_="t" #License set to t for trial, if you have a key, put it here.

# Functions
# Making sure the user is the right one.
Check_User() {
	if [ `/usr/bin/whoami` != 'TSM_Admin' ]; then
		printf "Switch to TSM_Admin please..\n"
		exit 1;
	else
	  printf "Nice, proceeding..\n"
	fi
}

Configure_Path() {
  source /etc/profile.d/tableau_server.sh
}

Configure_TSM() {
  cd /opt/tableau/tableau_server/packages/scripts."${tsm_version}"
  sudo ./initialize-tsm --accepteula
  Configure_Path
  tsm licenses activate "${license_}"
  tsm register --file "${registration_file}"
  tsm settings import -f "${init_settings_file}" && printf "Imported init settings.\n"
  tsm pending-changes apply
  tsm initialize && tsm start
  printf "Done, please proceed to the post install script.\n"
}

# Main function to simply call on all the other functions.
main() {
  Check_User
  Configure_TSM
}

main
