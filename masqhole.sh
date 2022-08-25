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
	# Add address listen prompt
	function MASQ_PROMPT() {
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
                	[Nn]* ) MASQ_PROMPT;;
                	* ) printf '\033[0;31mERROR: Incorrect input value. Please input (Y/N) or (y/n).\033[0m\n';
                    	MASQ_PROMPT;;
		esac
	}
	function NETMAN_CONFIG() {
        	cp /etc/resolv.conf /etc/resolv.conf.bak;
                touch /etc/resolv.conf;
                printf 'nameserver 127.0.0.1' >> /etc/resolv.conf;
                sed '/\[main\]/a dns=none' /etc/NetworkManager/NetworkManager.conf >> /etc/NetworkManager/NetworkManager.conf;
                sudo systemctl restart NetworkManager;
	}
	function DNSMASQ_CONFIG() {
		cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak;
                printf '### MASQHOLE CONFIGURATION ###\n' >> /etc/dnsmasq.conf;
                printf 'addn-hosts /etc/masqhole.list\n' >> /etc/dnsmasq.conf;
		# TODO add listen address
		# TODO add listen interface
		systemctl stop dnsmasq;
		systemctl enable dnsmasq;
		systemctl start dnsmasq;
                if [ $(systemctl is-active dnsmasq) != 'active' ]
                then
                        printf '\033[0;31mFATAL: dnsmasq not active. It is likely failing on start. Unable to recover.\033[0m\n';
			exit;
                fi

	}
	MASQ_PROMPT;
	if [ $1 = "s" ]
	then 
		printf 'Setting up dnsmasq as an external DNS server. \n';
		DISTRO_INST;
		MASQLIST;
		RESOLVED_OFF;
		# TODO server setup
		# TODO add resolv.conf
		# TODO update NetworkManager
		# TODO if no NM --> how to handle resolv.conf?
		# TODO add addn-hosts
	        # TODO add listen interface
		# TODO add listen address
		exit;
	fi
	if [ $1 = "u" ]
	then
		printf 'Setting up dnsmasq for local system use only. \n';
		DISTRO_INST;
		MASQLIST;
		RESOLVED_OFF;
		if [ $(systemctl is-active NetworkManager) = 'active' ] 
		then
			NETMAN_CONFIG;
		fi
		# TODO if no NM --> how to handle resolv.conf?
		DNSMASQ_CONFIG;
	fi
}
function MASQ_PROMPT() {
        read -p 'Setup dnsmasq for local or server use? (LOCAL/SERVER) ' LS
        case $LS in
                LOCAL|local ) SETUP_MASQ 'u';;
                SERVER|server ) SETUP_MASQ 's';;
                * ) printf '\033[0;31mERROR: Incorrect input value. ';
                    printf 'Please input (SERVER/server) or (LOCAL/local).\033[0m\n';;
	esac
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
