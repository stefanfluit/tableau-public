#!/usr/bin/env bash

# Author: Stefan Fluit
# Target: Setup new CentOS machine for use with Tableau Server 2019.2.3
# Usage: Please change names and variables and you should be good. 
# Expected environment consists of freshly installed CentOS 7.x instance.

# Error code explanation:
# Error code: 1, error, run script as sudo by typing "sudo !!" or switch to root.
# Error code: 10, error, no users defined in array.

# Set Bash behaviour
set -o errexit      #Exit on uncaught errors
set -o pipefail 	#Fail pipe on first error

# Variables
# Var for SSHD settings
declare script_location="/var/tableau-public/"
declare sshd_location="/etc/ssh/sshd_config"
declare sshd_config="${script_location}files/linux-files/sshd_config"
# Hostname variables needed for NTP and /etc/hosts.
declare hostname="hostname.domain.com"
declare timezone="Europe/Amsterdam" # https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
# Variables needed for kernel patch. 
declare grub_Config="/boot/grub2/grub.cfg"
declare kernel_Type="kernel-ml"
# Variables needed for repo, to eventually download latest ml kernel. 
declare repo_Gpg="https://www.elrepo.org/RPM-GPG-KEY-elrepo.org"
declare repo_Down="http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm"
# Download links for Tableau.
declare DL_Link="https://downloads.tableau.com/esdalt/2019.2.3/tableau-server-2019-2-3.x86_64.rpm"
declare DL_Progr="tableau-server-2019-2-3.x86_64.rpm"
# SSH public keys.
declare Key_user="${script_location}files/ssh-keys/key_user" # Change to user, add row for more users, and match the filename with pub key.
# Database driver variables. 
declare PostgresDriver="https://downloads.tableau.com/drivers/linux/yum/tableau-driver/tableau-postgresql-odbc-09.06.0500-1.x86_64.rpm"
declare PostgresFile="tableau-postgresql-odbc-09.06.0500-1.x86_64.rpm"
declare MysqlCommunity="https://dev.mysql.com/get/mysql80-community-release-el7-3.noarch.rpm"
declare MysqlRPM="mysql80-community-release-el7-3.noarch.rpm"
declare MariadbLink="https://downloads.mariadb.com/Connectors/odbc/connector-odbc-3.1.2/mariadb-connector-odbc-3.1.2-ga-rhel7-x86_64.tar.gz"
declare MariadbTar="mariadb-connector-odbc-3.1.2-ga-rhel7-x86_64.tar.gz"
# TSM User password. 
declare Tsm_Passwd=$(cat /tmp/tableau-transip/files/passwd/tsm-admin.txt)
declare HostsFile="${script_location}files/linux-files/hosts"
# SystemD units and timer variable for automated backup of TSM. 
declare SystemD_Unit="${script_location}files/systemd/tsmbackup.service"
declare SystemD_Timer="${script_location}files/systemd/tsmbackup.timer"
declare SystemD_Location="/etc/systemd/system"
# The actual backupscript that's gonna be called on by the systemD unit.
declare Backup_Script="${script_location}files/backup-script.sh"
declare BackupScript_Location="/var/scripts/backup-script.sh"
declare Tsm_User="TSM_Admin"
declare aws_script="${script_location}push-to-aws.sh"

# Arrays
# This is the array the user_add function reads from. Define users you want to add here. Note that these users will be added to sudo users.
declare -a users=(
  "User 1.."
  "user 2.."
  "Etc.."
)

# Array with programs to install, used by depends. function.
declare -a InstallPrograms=(
	"yum-utils"
	"vim"
	"device-mapper-persistent-data"
	"lvm2"
	"python36u"
	"wget"
	"yum-plugin-fastestmirror"
	"htop"
	"zip"
	"mtr"
	"samba-client"
	"unixODBC"
	"samba"
	"cifs-utils"
	"sshpass"
	"nfs-utils"
	"nfs-utils-lib"
)

# Functions
# Making sure the user has sudo rights or is root. 
Check_Sudo() {
	if [ `/usr/bin/whoami` != 'root' ];then
		printf "Error: run script with sudo\n"
		exit 1;
	fi
}

# A for loop to install dependencies in array above, and called on by Update_Function.
InstallDependencies() {
	local -a InstallPrograms=(${@})
	for i in "${InstallPrograms[@]}"; do
		printf "Installing %i." "${i}"
		yum -y install "${i}" >> /dev/null || true
		echo "Done with $i, proceeding.."
	done
}

# Updating the system and installing stuff we need. 
Update_Function() {
	printf "Updating system and installing programs. This process might take a while.\n"
	yum update -y >> /dev/null || true
	printf "Running more updates..\n"
	yum -y install https://centos7.iuscommunity.org/ius-release.rpm >> /dev/null || true
	yum install epel-release -y >> /dev/null || true
	printf "Running more updates..\n"
	yum -y install yum-plugin-fastestmirror >> /dev/null || true
	InstallDependencies "${InstallPrograms[@]}"
}

# Copying keys from user to their .ssh directorys, not the cleanest way to do this but it works.
# Just fill in the username and make sure the key file is there. For more users simply copy the line.
CopyKeys() {
  printf "Copy user SSH keys..\n"
	cat "${Key_user1}" > /home/user1/.ssh/authorized_keys
}

# Adding users, creating homedir and setting permissions and dir's up for SSH access. 
User_Add() {
	[[ $# -ge 1 ]] || return 10
	local -a users=(${@})
	for user in "${users[@]}"; do
		useradd -m "${user}"
		usermod -aG wheel "${user}"
   		mkdir -m700 "/home/${user}/.ssh"
   	 	chown -R "${user}:${user}" "/home/${user}/.ssh"
   		touch "/home/${user}/.ssh/authorized_keys"
   		chmod 600 "/home/${user}/.ssh/authorized_keys"
   		chown "${user}:${user}" /home/"${user}"/.ssh/*
	done
	CopyKeys
}

# Misc settings for timezone, route, etc.
Misc_Settings() {
	# Setting time zone via NTP
	timedatectl set-timezone "${timezone}"
	timedatectl set-ntp yes
	# Uncommenting an option that will eliminate the need for passwords. 
	sed -i "s/^#\s%wheel/%wheel/" /etc/sudoers
	# Both nodes into hosts file for TSM to work properly
	cat "${HostsFile}" > /etc/hosts
	# Overriding SSHD config with a more secure version
	cat "${sshd_config}" > "${sshd_location}" && systemctl restart sshd
	# Settings passwd for TSM_Admin
	echo "${Tsm_Passwd}" | passwd TSM_Admin --stdin 
}

# Setting the hostname.
Hostname_Key() {
	hostn=$(cat /etc/hostname)
	newhost="${hostname}"
	sed -i "s/$hostn/$newhost/g" /etc/hosts
	sed -i "s/$hostn/$newhost/g" /etc/hostname
}

# Installing several DB drivers we need for accessing data-sources.
# This was a little function i needed for production, left it hear if someone might need one or two, safe to comment out.
DB_Drivers() {
	wget "${PostgresDriver}"
	yum -y localinstall "${PostgresFile}"
	wget "${MysqlCommunity}" && yum -y localinstall "${MysqlRPM}"
	yum update -y mysql-community-release && yum -y install mysql-connector-odbc || true
	wget "${MariadbLink}" && tar xfzv "${MariadbTar}" && install lib64/libmaodbc.so /usr/lib64/
}

# Updating the kernel to something more sane than 3.x..
Kernel_Patch() {
	rpm --import "${repo_Gpg}"
	rpm -Uvh "${repo_Down}"
	yum -y --enablerepo=elrepo-kernel install "${kernel_Type}"
	grub2-set-default 0 && grub2-mkconfig -o "${grub_Config}"
}

# Making sure you reboot.
Reboot_Function() {
    read -p "Reboot now? (y/n) " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        sleep 2 && reboot now
    else
		    printf "You will have to, eventually.\nn"
    fi
}

# Setting up systemd based backup-script.
Setup_Systemd_Backup() {
	printf "Setting up systemd unit\n"
	mkdir -p /var/scripts/log/backup-logs
	cp "${Backup_Script}" "${BackupScript_Location}"
  cp "${SystemD_Unit}" "${SystemD_Location}"
  cp "${SystemD_Timer}" "${SystemD_Location}"
  systemctl daemon-reload
  systemctl enable synology-backup.service
  chown -R "${Tsm_User}}":"${Tsm_User}}" /var/scripts/*
  chown -R "${Tsm_User}}":"${Tsm_User}}" "${SystemD_Location}"/tsmbackup.*
  cp "${aws_script}" /var/scripts && chmod +x /var/scripts/push-to-aws.sh
}

# Configuring firewalld
Firewalld_Configurator() {
    systemctl enable firewalld || true
    systemctl start firewalld || true
    firewall-cmd --zone=internal --change-interface=eth1 --permanent
	  firewall-cmd --reload # Need reload to add rules.
	  firewall-cmd --zone=internal --permanent --add-port=80/tcp # Port for Tableau HTTP traffic.
	  firewall-cmd --zone=internal --permanent --add-port=443/tcp # Port for Tableau HTTPS traffic.
	  firewall-cmd --zone=internal --permanent --add-port=8850/tcp # Port for HTTPS TSM traffic.
	  firewall-cmd --zone=internal --permanent --add-port=27000-27010/tcp # Ports for TSM License server.
	  firewall-cmd --zone=internal --permanent --add-port=8000-9000/tcp # Ports for TSM cluster communication.
	  firewall-cmd --reload # Reload to activate new rules.
}

# Actually downloading and installing Tableau.
Get_Tableau() {
	printf "Downloading Tableau..\n"
	wget "${DL_Link}"
	printf "Installing Tableau and ignoring the output.. go get some coffee?\n"
	chmod 777 "${DL_Progr}" && yum -y install "${DL_Progr}" >> /dev/null
	printf "Done\n"
}

# Main function to call on functions in desired order.
main() {
	# Making sure you have the right permissions, and updating system and installing dependencies we need. 
	Check_Sudo && Update_Function
	# Adding users to the system, and TSM_Admin in advance, to manage tsm later. Echo'ing keys into directory as well for secure login. 
	User_Add "${users[@]}"
	# Setup SSH between nodes
	Setup_SSH && Connect_Nas && SCP_keyFile && Move_keyFiles
	# Miscellanious settings and SSH key for root user of the system as well as SSH between nodes. 
	Misc_Settings && Hostname_Key
	# Copy all the systemd unit files to the folder and enable them after a systemd reload. This function is only in this script, since backups of node 2 are not important in any way. 
	Setup_Systemd_Backup
	# Installing database drivers allready, and installing the latest mainline kernel. 
	DB_Drivers && Kernel_Patch
	# Configuring firewall and downloading, and installing, Tableau.
	Change_Network_Manager && Firewalld_Configurator && Get_Tableau
	# Proposing reboot.
	Reboot_Function
	# Run the next script please.
}

main
