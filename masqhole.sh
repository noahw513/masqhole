#!/bin/bash
# Creates the arrays used by the interface/IPv4 address binding prompt
function CREATE_ARRS() {
	declare -a ADDRESS_ARR=();
	declare -a INTERFACE_ARR=();
	declare -A NET_ASSOC_ARR=();
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
        if [ $DEBUG = 1 ]
        then
                printf 'NET_ASSOC_ARR: \n';
                for KEY in ${!NET_ASSOC_ARR[@]};
                do
                        printf '[%s] = %s\n' $KEY ${NET_ASSOC_ARR[$KEY]};
                done
        fi
}
# Determines distro of target machine & installs pkgs with correct pkg mgr
# ONLY supports RHEL & Debian based OSes
function DISTRO_INST() {
	local DEBUG=0;
	local OS_RELEASE=$(cat /etc/os-release | grep ID= | head -n 1);
	local DISTRO=${OS_RELEASE#*=};
	local PKG_LIST="dig dnsmasq wget";
	# Debug
	if [ $DEBUG = 1 ]
	then
		printf 'OS_RELEASE = %s\n' $OS_RELEASE;
		printf 'DISTRO = %s\n' $DISTRO;
	fi
	# Prod
	if [ $DEBUG = 0 ] 
	then
		# If target machine is RHEL derived use dnf
		if [ $DISTRO = 'fedora' ] || [ $DISTRO = 'centos' ] || [ $DISTRO = 'rhel' ]
		then
			for PKG in $PKG_LIST
			do
				dnf install $PKG -y &> /dev/null;
			done
		fi
		# If target machine is debian derived use apt
		if [ $DISTRO = 'debian' ] || [ $DISTRO = 'ubuntu' ] 
		then
			for PKG in $PKG_LIST 
			do
				apt install $PKG -y &> /dev/null;
			done
		fi
	fi
}
# Turns off systemd-resolved
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
# Pulls the sinkhole list
function MASQLIST() {
	# Put sinkhole list in /etc/ as masqhole.list --> /etc/masqhole.list
	wget https://raw.githubusercontent.com/noahw513/Giant-DNS-Blocklist/main/master-block.list -O /etc/masqhole.list &> /dev/null;
	if [ $? != 0 ]
	then
		printf 'FATAL: Failed to pull masqhole list.\n';
		exit;
	else
	        # General error handling	
		if [ -f /etc/masqhole.list ]
		then
			return 0;
		else 
			printf 'FATAL: Uknown error. Masqhole list, "masqhole.list", not present in /etc/.\n';
			exit;
		fi
	fi
}
# Entry point
# Validates script is being run as root
function AS_ROOT_ENTRY() {
        if [ $(id -u) != 0 ]
        then
                printf 'FATAL: Script must be run as root.\n';
                exit;
        fi
        if [ $(id -u) = 0 ]
        then
                printf 'Beginning masqhole setup.\n';
		DISTRO_INST;
		# MASQ_PROMPT;
        fi
}
AS_ROOT_ENTRY;
