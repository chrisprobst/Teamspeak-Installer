#!/bin/bash

# Usage
# service teamspeak start
# service teamspeak stop
# service teamspeak restart
# service teamspeak status

# Set some styles
bold=`tput bold`
alert=`tput setaf 1`
info=`tput setaf 3`
normal=`tput sgr0`

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#\tThis script must be run as root." 1>&2
    exit 1
fi

bit=$(uname -a)
serverip=$(wget -qO- http://ipecho.net/plain ; echo)

### For future use in setting up multiple instances (remove triples hashes from code below)
### Will require NPL License @ http://npl.teamspeakusa.com/ts3npl.php
### Will require within script append all instances of ts3server with ${ts3servername} (e.g. ts3server-${ts3servername})
### Also append service name and init filename
if id -u ts3user >/dev/null 2>&1; then

        echo "TS3 system account already configured, skipping to server setup..."
        
        # Go to the ts3user directory
        cd /home/ts3user
        
        ### printf "\n${bold}Note:{normal} Alphanumeric and dashes only, everything else will be trimmed.\n"
        ### read -e -p "Teamspeak 3 Server Name: " -i "server-name" dirtyts3servername
	
	### Only alphanumeric names, we'll make sure of that
	### export ts3servername="`echo -n "${dirtyts3servername}" | tr -cd '[:alnum:] [:space:]' | tr '[:space:]' '-'  | tr '[:upper:]' '[:lower:]'`"
else
	# Create TS3 user account
	printf "\n${bold}Creating Teamspeak 3 system account${normal}\n"
	useradd -d /home/ts3user -m ts3user

	# Set TS3 account password
	# printf "\n${bold}Creating Teamspeak 3 system account password${normal}\n"
	# passwd ts3user

	# Set permissions on the new ts3user directory
	chmod 755 /home/ts3user

	# Go to the ts3user directory
	cd /home/ts3user
	
	### printf "\n${bold}Note:{normal} Alphanumeric and dashes only, everything else will be trimmed.\n"
	### read -e -p "Teamspeak 3 Server Name: " -i "server-name" ts3servername
	
	### Only alphanumeric names, we'll make sure of that
	### export cleants3servername="`echo -n "${ts3servername}" | tr -cd '[:alnum:] [:space:]' | tr '[:space:]' '-'  | tr '[:upper:]' '[:lower:]'`"

fi

# Download, unpack, and install the Teamspeak application
if [[ ${bit} == *x86_64* ]]; then
	# You're running 64 bit
	printf "\n${bold}64 bit install running...${normal}\n"
	wget http://dl.4players.de/ts/releases/3.0.11.2/teamspeak3-server_linux-amd64-3.0.11.2.tar.gz -O teamspeak3-64.tar.gz
	tar xzf teamspeak3-64.tar.gz
	rm -f teamspeak3-64.tar.gz
	mv teamspeak3-server_linux-amd64 ts3server
	cd ts3server
	chmod +x ts3server_startscript.sh
	printf "\nMake sure to copy your ${bold}loginname, password, and token${normal} during the next step"
	printf "\n${bold}Note:${normal} The installer will not continue until you copy the token (CTRL+C)\n"
	read -p "Press ${bold}[Enter]${normal} to continue..."
else 
	# You're running 32 bit
	printf "\n${bold}32 bit install running...${normal}\n"
	wget http://dl.4players.de/ts/releases/3.0.11.2/teamspeak3-server_linux-x86-3.0.11.2.tar.gz -O teamspeak3-32.tar.gz
	tar xzf teamspeak3-32.tar.gz
	rm -f teamspeak3-32.tar.gz
	mv teamspeak3-server_linux-x86 ts3server
	cd ts3server
	chmod +x ts3server_startscript.sh
	printf "\nMake sure to copy your ${bold}loginname, password, and token${normal} during the next step"
	printf "\n${bold}Note:${normal} The installer will not continue until you copy the token (CTRL+C)\n"
	read -p "Press ${bold}[Enter]${normal} to continue..."
fi

# Create the ini file
echo "machine_id=
default_voice_port=9987
voice_ip=0.0.0.0
licensepath=
filetransfer_port=30033
filetransfer_ip=0.0.0.0
query_port=10011
query_ip=0.0.0.0
query_ip_whitelist=query_ip_whitelist.txt
query_ip_blacklist=query_ip_blacklist.txt
dbplugin=ts3db_sqlite3
dbpluginparameter=
dbsqlpath=sql/
dbsqlcreatepath=create_sqlite/
dbconnections=10
logpath=logs
logquerycommands=0
dbclientkeepdays=30
logappend=0
query_skipbruteforcecheck=0" >> /home/ts3user/ts3server/ts3server.ini

# Change machine_id to 1
sed -i -e "s|machine_id=|machine_id=1|g" /home/ts3user/ts3server/ts3server.ini

# Insert this machine's IP into the voice_ip field
sed -i -e "s|voice_ip=0.0.0.0|voice_ip=$serverip|g" /home/ts3user/ts3server/ts3server.ini

# Insert this machine's IP into the filetransfer_ip field
sed -i -e "s|filetransfer_ip=0.0.0.0|filetransfer_ip=$serverip|g" /home/ts3user/ts3server/ts3server.ini

# Insert this machine's IP into the query_ip field
sed -i -e "s|query_ip=0.0.0.0|query_ip=$serverip|g" /home/ts3user/ts3server/ts3server.ini

# Edits the startup script to load the ini file
sed -i 's|COMMANDLINE_PARAMETERS="${2}"|COMMANDLINE_PARAMETERS="${2} inifile=ts3server.ini"|g' /home/ts3user/ts3server/ts3server_startscript.sh

read -e -p "Teamspeak 3 Server Voice Port: " -i "9987" ts3voiceport
sed -i -e "s|default_voice_port=9987|default_voice_port=$ts3voiceport|g" /home/ts3user/ts3server/ts3server.ini

read -e -p "Teamspeak 3 Server File Transfer Port: " -i "30033" ts3fileport
sed -i -e "s|filetransfer_port=30033|filetransfer_port=$ts3fileport|g" /home/ts3user/ts3server/ts3server.ini

read -e -p "Teamspeak 3 Server Query Port: " -i "10011" ts3queryport
sed -i -e "s|query_port=9987|query_port=$ts3queryport|g" /home/ts3user/ts3server/ts3server.ini

printf "\n${bold}Creating Teamspeak 3 service file${normal}\n"

# Setup the Teamspeak service file
if [ -f /etc/redhat-release ]; then
	echo "#!/bin/sh
	# chkconfig: 2345 95 20
	# description: Control TeamSpeak3 Server
	# processname: /home/ts3user/ts3server/ts3server_runscript.sh
	cd /home/ts3user/ts3server
	case \"\$1\" in
	'start')
	su ts3user -c \"/home/ts3user/ts3server/ts3server_startscript.sh start\"
	;;
	'stop')
	su ts3user -c \"/home/ts3user/ts3server/ts3server_startscript.sh stop\"
	;;
	'restart')
	su ts3user -c \"/home/ts3user/ts3server/ts3server_startscript.sh restart\"
	;;
	'status')
	su ts3user -c \"/home/ts3user/ts3server/ts3server_startscript.sh status\"
	;;
	*)
	echo \"Usage \$0 start|stop|restart|status\"
	esac" > /etc/rc.d/init.d/teamspeak
else
	echo "#!/bin/sh
	# chkconfig: 2345 95 20
	# description: Control TeamSpeak3 Server
	# processname: /home/ts3user/ts3server/ts3server_runscript.sh
	cd /home/ts3user/ts3server
	case \"\$1\" in
	'start')
	su ts3user -c \"/home/ts3user/ts3server/ts3server_startscript.sh start\"
	;;
	'stop')
	su ts3user -c \"/home/ts3user/ts3server/ts3server_startscript.sh stop\"
	;;
	'restart')
	su ts3user -c \"/home/ts3user/ts3server/ts3server_startscript.sh restart\"
	;;
	'status')
	su ts3user -c \"/home/ts3user/ts3server/ts3server_startscript.sh status\"
	;;
	*)
	echo \"Usage \$0 start|stop|restart|status\"
	esac" > /etc/init.d/teamspeak
fi

# Change permissions and ownership on the teamspeak files
chown -R ts3user:ts3user /home/ts3user
chmod +x /home/ts3user/ts3server/ts3server_startscript.sh

# Fixing common error @ http://forum.teamspeak.com/showthread.php/68827-Failed-to-register-local-accounting-service
# check if tmpfs is mounted, add entry to fstab if necessary
if ! mount|grep -q "/dev/shm"; then
	mount -t tmpfs tmpfs /dev/shm
	grep -q "/dev/shm" /etc/fstab || echo "tmpfs /dev/shm tmpfs rw 0 0" >> /etc/fstab
fi

# Initiate the Teamspeak service and boot at startup
if [ -f /etc/redhat-release ]; then
	chmod +x /etc/rc.d/init.d/teamspeak
	chkconfig --add teamspeak
	chkconfig --level 2345 teamspeak on
else
	chmod +x /etc/init.d/teamspeak
	update-rc.d teamspeak defaults
fi

# Do not start directly!
# service teamspeak start

printf "\n${bold}Install Complete!${normal}\n"
# printf "\n${bold}Teamspeak 3 is running @ $serverip:$ts3voiceport${normal}\n"
