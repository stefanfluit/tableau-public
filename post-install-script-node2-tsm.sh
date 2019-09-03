#!/usr/bin/env bash

# Author: Stefan Fluit
# Target: Post-install script for CentOS 7.x based Tableau cluster of 2 nodes.
# After you run the setup-node scripts, initialize the first node, generate bootstrap and add the other node.
# Then run this script on node 2.
# Note: this script needs to restart TSM 2 times. I also expect SSH access to be setup between nodes, will automate this later, for now just use the password.

# Set Bash behaviour
set -o errexit      # Exit on uncaught errors
set -o pipefail 	# Fail pipe on first error

# Variables
declare Tsm_User="TSM_Admin"
declare Scripts_Dir="/opt/tableau/tableau_server/packages/scripts.20192.19.0718.1543"

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

# Setting up the cluster on the additional node side.
Setup_Cluster() {
  sudo cp /home/TSM_Admin/bootstrap.json "${Scripts_Dir}"
  printf "Copied bootstrap to dir on node2.\n"
  cd "${Scripts_Dir}" && sudo ./initialize-tsm -b bootstrap.json -u "${Tsm_User}" -p "${Tsm_Passwd}" --accepteula
  printf "Done\n"
}

# Main function to call on functions we wrote.
main() {
  Check_User
    # Init TSM with the bootstrap file generated on the first node, to create and join a cluster.
    Setup_Cluster
}

main
