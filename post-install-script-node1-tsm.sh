#!/usr/bin/env bash

# Author: Stefan Fluit
# Target: Post-install script for CentOS 7.x based Tableau cluster of 2 nodes.
# After you run the setup-node scripts, initialize the first node, generate bootstrap and add the other node. 
# Then run this script on node 1.
# Note: this script needs to restart TSM 2 times. I also expect SSH access to be setup between nodes, will automate this later, for now just use the password.

# Set Bash behaviour
set -o errexit    # Exit on uncaught errors
set -o pipefail 	# Fail pipe on first error

# Variables
declare script_location="/var/tableau-public/"
declare node2="Enter the fqdn or IP address for node 2."
declare Audit_Value="wgserver.audit_history_expiration_days"
declare Cert_File="${script_location}files/ssl/wildcard.datlinq.com.crt"
declare Key_File="${script_location}files/ssl/wildcard.datlinq.com.key"
declare Ca_File="${script_location}files/ssl/wildcard.datlinq.com.ca"
declare Tsm_Passwd=$(cat ${script_location}files/passwd/tsm-admin.txt)
declare Tsm_User="TSM_Admin"
declare SMTP_Setup="${script_location}files/tableau-init-files/smtp.json"
declare Header_Logo="${script_location}files/branding-images/header-logo.png"
declare Signin_Logo="${script_location}files/branding-images/signin-logo.png"
declare ServerName="Set server name here, e.g. '<Company> Insights'" # Will be shown in browser tab title.
declare repo_passwd="Enter password here for PostgreSQL user"
declare repo_user="readonly" # Change to 'tableau' if you want write acces, i discourage you to do so, but there are use cases.

# Functions
# Function used to export tsm binarys to current path in session to access tsm commands without starting a new session.
Configure_Path() {
  source /etc/profile.d/tableau_server.sh
}

# Configuring TSM with several server side settings we need.
Tsm_Configurator() {
    printf "Setting system variables..\n"
    Configure_Path
    tsm login -u "${Tsm_User}" -p "${Tsm_Passwd}" || true
    tsm settings import -f "${SMTP_Setup}"
    tsm configuration set -k "${Audit_Value}" -v 730
    tsm security external-ssl enable --cert-file "${Cert_File}" --key-file "${Key_File}" --chain-file "${Ca_File}"
    tsm pending-changes apply
}

# Configuring cluster with bootrstrap file from init node.
Setup_Cluster() {
  Configure_Path
  printf "Setting up cluster..\n"
  tsm start
  tsm topology nodes get-bootstrap-file --file /home/TSM_Admin/bootstrap.json
  scp /home/TSM_Admin/bootstrap.json TSM_Admin@"${node2}":/home/TSM_Admin/bootstrap.json
}

# Branding setup like logos and name, etc.
Setup_Branding() {
    Configure_Path
    printf "Setting up branding..\n"
    tsm login -u "${Tsm_User}" -p "${Tsm_Passwd}" || true
    tsm customize --server-name "${ServerName}"
    tsm customize --header-logo "${Header_Logo}"
    tsm customize --signin-logo "${Signin_Logo}"
    tsm pending-changes apply
    tsm data-access repository-access enable --repository-username "${repo_user}" --repository-password "${repo_passwd}"
    Setup_Cluster
}

# Main function to call functions we wrote.
main() {
    # Tsm configuration for SMTP and that kind of stuff, as well as setup cluster. 
    Tsm_Configurator
    # Setup branding and start TSM. 
    Setup_Branding
    printf "Please visit https://tableau.datlinq.com\n"
}

main
