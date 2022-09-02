#!/bin/bash
declare -a ADDRESS_ARR=();
declare -a INTERFACE_ARR=();
declare -A NET_ASSOC_ARR=();
# Creates the arrays used by the interface/IPv4 address binding prompt
function CREATE_ARRS() {
	local COUNT=1;
        local DEBUG=0;
	local STR_ADDRESSES=$(ip -4 addr | sed -n -e 's/inet //p' | sed 's/^ *//g' | cut -d' ' -f1);
	local STR_INTERFACES=$(ls /sys/class/net/);
	# Setup interfaces indexed array
        for INTERFACE in $STR_INTERFACES;
        do
                INTERFACE_ARR+=($INTERFACE);
        done
        # Setup IPv4 addresses indexed array
        for ADDRESS in $STR_ADDRESSES;
        do
                ADDRESS_ARR+=($ADDRESS);
        done
        # Setup network assoc array
        for INTERFACE in ${INTERFACE_ARR[*]};
        do
                NET_ASSOC_ARR+=( [$INTERFACE]=${ADDRESS_ARR[@]:($COUNT - 1):$COUNT} );
                ((COUNT++));
        done
        # Debug
        if [ $DEBUG = 1 ];
        then
		printf '\033[0;33mDEBUG: ADDRESS_ARR = \033[0m\n';
		for ADDR in ${ADDRESS_ARR[@]};
		do
			printf '\033[0;33m%s\033[0m\n' $ADDR;
		done
		printf '\033[0;33mDEBUG: INTERFACE_ARR = \033[0m\n';
		for INT in ${INTERFACE_ARR[@]};
		do
			printf '\033[0;33m%s\033[0m\n' $INT;
		done
                printf '\033[0;33mDEBUG: NET_ASSOC_ARR = \033[0m\n';
                for KEY in ${!NET_ASSOC_ARR[@]};
                do
                        printf '\033[0;33m[%s] = %s\033[0m\n' $KEY ${NET_ASSOC_ARR[$KEY]};
                done
        fi
	MASQ_PROMPT;
}
# Determines distro of target machine & installs pkgs with correct pkg mgr
# ONLY supports RHEL & Debian based OSes
function DISTRO_INST() {
	local DEBUG=0;
	local OS_RELEASE=$(cat /etc/os-release | grep ID= | head -n 1);
	local DISTRO=${OS_RELEASE#*=};
	local PKG_LIST="dig dnsmasq wget";
	# Debug
	if [ $DEBUG = 1 ];
	then
		printf '\033[0;33mDEBUG: OS_RELEASE = %s\033[0m\n' $OS_RELEASE;
		printf '\033[0;33mDEBUG: DISTRO = %s\033[0m\n' $DISTRO;
	fi
	# Prod
	if [ $DEBUG = 0 ]; 
	then
		# If target machine is RHEL derived use dnf
		if [ $DISTRO = 'fedora' ] || [ $DISTRO = 'centos' ] || [ $DISTRO = 'rhel' ];
		then
			for PKG in $PKG_LIST
			do
				dnf install $PKG -y &> /dev/null;
			done
		fi
		# If target machine is debian derived use apt
		if [ $DISTRO = 'debian' ] || [ $DISTRO = 'ubuntu' ];
		then
			for PKG in $PKG_LIST 
			do
				apt install $PKG -y &> /dev/null;
			done
		fi
		# General err handling
		if [ $DISTRO != 'fedora' ] && [ $DISTRO != 'centos' ] && [ $DISTRO != 'rhel' ] && [ $DISTRO = 'debian' ] && [ $DISTRO != 'ubuntu' ];
		then
			printf '\033[0;31mFATAL: Unsupported distribution. Exiting.\033[0m\n';
		fi
	fi
}
# Turns off systemd-resolved
function RESOLVED_OFF() {
	local RUN_STAT=$(systemctl is-active systemd-resolved);
	local ENABLED_STAT=$(systemctl is-enabled systemd-resolved);
	if [ $RUN_STAT = "active" ]; 
	then 
		systemctl stop systemd-resolved &> /dev/null;
		if [ $? != 0 ];
		then
			printf '\033[0;31mFATAL: Failed to stop systemd-resolved. Exiting.\033[0m\n';
			exit;
		fi
	fi
	if [ $ENABLED_STAT = "enabled" ];
	then
		systemctl disable systemd-resolved &> /dev/null;
		if [ $? != 0 ];
		then
			printf '\033[0;31mFATAL: Failed to disabled systemd-resolved. Exiting.\033[0m\n';
			exit;
		fi
	fi
	return 0;
}
# Pulls the sinkhole list
function MASQ_LIST() {
	# Put sinkhole list in /etc/ as masqhole.list --> /etc/masqhole.list
	wget https://raw.githubusercontent.com/noahw513/Giant-DNS-Blocklist/main/master-block.list -O /etc/masqhole.list &> /dev/null;
	if [ $? != 0 ]
	then
		printf 'FATAL: Failed to pull masqhole list.\n';
		exit;
	else
	        # General error handling	
		if [ ! -f /etc/masqhole.list ];
		then
			printf '\033[0;31mFATAL: Uknown error. Masqhole list, "masqhole.list", not present in /etc/.\033[0m\n';
			exit;
		fi
	fi
}
# Setup MASQ
function MASQ_SETUP {
	local DEBUG=0;
	local SELECTED_INTERFACE=$1;
	if [ $DEBUG = 1 ]
	then
		printf '\033[0;33mDEBUG: Passed INTERFACE_PROMPT = %s\033[0m\n' $1;
		printf '\033[0;33mDEBUG: SELECTED_INTERFACE = %s\033[0m\n' $SELECTED_INTERFACE;
	fi
	# Setup addn-hosts
	# Setup interface binding
	# Setup start dnsmasq
	# Setup enable dnsmasq
	# Setup testing of sinkhole with dig
}
# Setup prompt
function MASQ_PROMPT {
	local DEBUG=0;
	# Show user available interfaces
	printf 'Available interfaces:\n';
	for KEY in ${!NET_ASSOC_ARR[@]};
	do
		printf '\033[0;32m%s: %s\033[0m\n' $KEY ${NET_ASSOC_ARR[$KEY]};
	done
	read -p 'Which interface would you like to bind to? ' INTERFACE_PROMPT;
	# Debug user prompt input
	if [ $DEBUG = 1 ];
	then
		printf '\033[0;33mDEBUG: INTERFACE_PROMPT = %s\033[0m\n' $INTERFACE_PROMPT;
	fi
	if [[ "${INTERFACE_ARR[*]}" =~ "$INTERFACE_PROMPT" ]]
	then
		#DISTRO_INST;
		#MASQ_LIST;
		#RESOLVED_OFF;
		MASQ_SETUP "$INTERFACE_PROMPT";	
		# Do something here
	fi
	if [[ ! "${INTERFACE_ARR[*]}" =~ "$INTERFACE_PROMPT" ]]
	then
		clear >$(tty);
		printf '\033[0;31mERR: %s is not an available interface.\033[0m\n' $INTERFACE_PROMPT;
		MASQ_PROMPT;
	fi
}
# Entry point
# Validates script is being run as root
function AS_ROOT_ENTRY() {
        if [ $(id -u) != 0 ];
        then
                printf '\033[0;31mFATAL: Script must be run as root.\033[0m\n';
                exit;
        fi
        if [ $(id -u) = 0 ];
        then
                printf 'Beginning masqhole setup.\n';
		CREATE_ARRS;
        fi
}
AS_ROOT_ENTRY;
