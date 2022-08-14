#!/bin/bash
OS_RELEASE=$(cat /etc/os-release | grep ID= | head -n 1);
OS_RELEASE=${OS_RELEASE#*=};
PKG_LIST="dnsmasq wget";
function DISTRO_INST() {
	local OS_RELEASE=$(cat /etc/os-release | grep ID= | head -n 1);
	local DISTRO=${OS_RELEASE#*=};
	if [ $DISTRO = 'fedora' ] || [ $DISTRO = 'centos' ] || [ $DISTRO = 'rhel' ]
	then
		for PKG in $PKG_LIST
		do
			dnf install $PKG &> /dev/null;
		done
	fi
	if [ $DISTRO = 'debian' ] || [ $DISTRO = 'ubuntu' ] 
	then
		for PKG in $PKG_LIST 
		do
			apt install $PKG &> /dev/null;
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
			printf 'FATAL: Uknown error. Masqhole not present in /etc/.\n';
			exit;
		fi
	fi
}
function AS_ROOT() {
	if [ $(id -u) != 0 ]
	then
		printf 'FATAL: Script must be run as root.\n';
		exit;
	fi
}
function SETUP_MASQ() {

}
function SETUP_PROMPT() {
}
AS_ROOT;
MASQLIST;
DISTRO_INST;
RESOLVED_OFF;
