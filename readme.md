## Last version check:
* September 3rd, 2019.


# Tableau - Install scripts for CentOS & Tableau 2019.02.03

## Features

* Sets up server, users, permissions, kernel patch, DB drivers, and Tableau. 
* Please read the script thoroughly before running. 
* Supported OS: CentOS 7.x 
* Tested OS: CentOS 7.6

## Requirements

* Minimum of 8 (v) cores and 16GB RAM per server/instance/VPS.


## Download:

Get the latest version:
```
git clone https://github.com/stefanfluit/tableau-public.git
```

## Run

I suggest you pick a user to perform tasks, i use TSM_Admin user. The names of the scripts will
be clear on which user it has to run.
```
Node 1 & 2: git clone https://github.com/stefanfluit/tableau-public.git
Node 1 & 2: cd tableau-public
Node 1 & 2: sudo chmod +x *.sh
Node 1 & 2: sudo ./setup-script-node{1, 2}.sh
Node 1 & 2: Open a new session, log in as your user, and sudo switch to TSM_Admin
Node 1: sudo ./tsm-init-script.sh
Node 1: sudo ./post-install-script-node1.sh - Wait for it to finish
Node 2: sudo ./post-install-script-node2.sh

Now, as TSM_Admin on Node 1, execute the following command:
tabcmd initialuser --server localhost:80 --username "<new-admin-username>" 
Your Tableau install is now done. 
```
```
Mind that you need to add alot of files in this repo, it is best to fork and edit them. 
The formats are all easy going or easy to find on the internet, mainly Tableau documentation itself. 
```

## Files to edit
```
Branding images: there is a text file which says what my script expects to be there.
SSHD Config: I made some security enhancing changes to this, edit if you want to log in to SSH with root for instance. 
Passwd files: The passwords you will write down in these files, will be the passwords you need to log in to TSM. 
SSL: Add files for a secure connections with the TSM server. Don't forget to set DNS or in your hosts file.
Systemd: You can change the frequency of the backups in the timer, or run backup manually by running: sudo systemctl start tsmbackup.service
Tableau init files: Change these to your likening. SMTP is there for email. I did this with a JSON file because it enables you to use Google/Gmail, with SSL on. That button dissapeared from Tableau. 
The registration file needs your contact details. At least fill something in, null is not accepted. 
```

## Notes
```
- Check every variable and adjust them to your details. Also scan the functions, some of them might not suit your needs.
```

