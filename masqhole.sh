#!/bin/bash
OS_RELEASE=$(cat /etc/os-release | grep ID= | head -n 1);
OS_RELEASE=${OS_RELEASE#*=};
INTERFACES=$(ls /sys/class/net/);
PKG_LIST="dnsmasq wget";
function DISTRO_INST() {
	local OS_RELEASE=$(cat /etc/os-release | grep ID= | head -n 1);
	local DISTRO=${OS_RELEASE#*=};
	if [ $DISTRO = 'fedora' ] || [ $DISTRO = 'centos' ] || [ $DISTRO = 'rhel' ]
	then
		for PKG in $PKG_LIST
		do
			dnf install $PKG -y &> /dev/null;
		done
	fi
	if [ $DISTRO = 'debian' ] || [ $DISTRO = 'ubuntu' ] 
	then
		for PKG in $PKG_LIST 
		do
			apt install $PKG -y &> /dev/null;
		done
	fi
}
function RESOLVED_OFF() {
	local RUN_STAT=$(systemctl is-active systemd-resolved);
	local ENABLED_STAT=$(systemctl is-enabled systemd-resolved);
	if [ $RUN_STAT = "active" ] 
	then 
		systemctl stop systemd-resolved &> /dev/null;
		if [ $? != 0 ]
		then
			printf 'FATAL: Failed to stop systemd-resolved. Exiting.\n';
			exit;
		fi
	fi
	if [ $ENABLED_STAT = "enabled" ]
	then
		systemctl disable systemd-resolved &> /dev/null;
		if [ $? != 0 ]
		then
			printf 'FATAL: Failed to disabled systemd-resolved. Exiting.\n';
			exit;
		fi
	fi
	return 0;
}
function MASQLIST() {
	wget https://raw.githubusercontent.com/noahw513/Giant-DNS-Blocklist/main/master-block.list -O /etc/masqhole.list &> /dev/null;
	if [ $? != 0 ]
	then
		printf 'FATAL: Failed to pull masqhole list.\n';
		exit;
	else 
		if [ -f /etc/masqhole.list ]
		then
			return 0;
		else 
			printf 'FATAL: Uknown error. Masqhole list, "masqhole.list", not present in /etc/.\n';
			exit;
		fi
	fi
}
function SETUP_MASQ() {
	function INTERFACE_PROMPT() {
	while true;
	do
        	printf 'Available interfaces: ';
        	for INT in $INTERFACES
        	do
                	printf '\033[0;32m %s \033[0m' $INT;
        	done
        	printf '\n';
        	read -p 'Which interface would you like to bind to? ' INTERFACE;
        	printf 'You entered \033[0;32m %s\033[0m. ' $INTERFACE;
        	read -p 'Is this correct? (Y/N) ' YN;
        	break;
	done
	case $YN in
                [Yy]* ) ;;
                [Nn]* ) INTERFACE_PROMPT;;
                * ) printf '\033[0;31mERROR: Incorrect input value. Please input (Y/N) or (y/n).\033[0m\n';
                    INTERFACE_PROMPT;;
	esac
	}
	if [ $1 = "s" ]
	then 
		printf 'Setting up dnsmasq as an external DNS server. \n';
		DISTRO_INST;
		MASQLIST;
		RESOLVED_OFF;
		# TODO: Server setup
		exit;
	fi
	if [ $1 = "u" ]
	then
		printf 'Setting up dnsmasq for local system use only. \n';
		DISTRO_INST;
		MASQLIST;
		RESOLVED_OFF;
	        if [ $DISTRO = 'fedora' ] || [ $DISTRO = 'centos' ] || [ $DISTRO = 'rhel' ]
        	then
			NMSTAT=$(systemctl is-active NetworkManager);
			if [ $NMSTAT = 'active' ] 
			then
				cp /etc/resolv.conf /etc/resolv.conf.old;
				touch /etc/resolv.conf;
				printf 'nameserver 127.0.0.1' >> /etc/resolv.conf;
				sed '/\[main\]/a dns=none' /etc/NetworkManager/NetworkManager.conf >> /etc/NetworkManager/NetworkManager.conf;
				sudo systemctl restart NetworkManager;
			fi
		fi
		cp /etc/dnsmasq.conf /etc/dnsmasq.old
		printf '### MASQHOLE CONFIGURATION ###\n' >> /etc/dnsmasq.conf
		printf 'addn-hosts /etc/masqhole.list\n' >> /etc/dnsmasq.conf
		exit;
	fi
}
function MASQ_PROMPT() {
	while true; 
	do
    		read -p 'Setup dnsmasq for local system use only? ' YN
    		case $YN in
			[Yy]* ) SETUP_MASQ 'u';;
        		[Nn]* ) read -p 'Setup dnsmasq as an external DNS server? ' PROMPT
				case $PROMPT in
					[Yy]* ) SETUP_MASQ 's';;
					[Nn]* ) printf 'Invalid input. Exiting... \n'; break;;
				esac;;
   			* ) printf 'FATAL: Invalid user input or option selected. You must choose to setup dnsmasq as a local or external DNS server.\nExiting...\n'; break;;
    		esac
	done

}
function AS_ROOT_ENTRY() {
        if [ $(id -u) != 0 ]
        then
                printf 'FATAL: Script must be run as root.\n';
                exit;
        fi
        if [ $(id -u) = 0 ]
        then
                printf 'Beginning masqhole setup.\n';
		MASQ_PROMPT;
        fi
}
AS_ROOT_ENTRY;
