#!/bin/bash
#
# Copyright (C) 2021 matrix - Gabriele Gristina

MATRIX_RTL8187_PATCH="${PWD}/rtl8187-matrix.patch"
KALI_INJECTION_PATCH="${PWD}/kali-wifi-injection.patch"
BACKPORTS_URL="https://cdn.kernel.org/pub/linux/kernel/projects/backports/stable/v5.10.16/backports-5.10.16-1.tar.xz"
INJECTION_PATCH_URL="https://gitlab.com/kalilinux/packages/linux/raw/kali/master/debian/patches/features/all/kali-wifi-injection.patch?inline=false"
MATRIX_PATCH_URL="https://raw.githubusercontent.com/matrix/backports-rtl8187/master/rtl8187-matrix.patch"

CLEAN=0
BUILD=0
INSTALL=0
UNINSTALL=0

OS_DIST=$(lsb_release -is 2>/dev/null)

if [[ -z ${OS_DIST} ]]; then
	echo "! Missing lsb_release ... probably wrong OS" 1>&2
	exit 2
fi

if [[ ${OS_DIST} != "Kali" ]]; then
	if [[ $EUID -eq 0 ]]; then
		echo "! This script must not be run as root" 1>&2
		exit 1
	fi
else
	if [[ $EUID -ne 0 ]]; then
		echo "! This script must be run as root" 1>&2
		exit 1
	fi
fi

function usage()
{
	echo -e "> Usage $0 <options>\n\noptions:\n" \
		"\t-c\t Cleanup workdir.\n" \
		"\t-b\t Build rtl8187 kernel wireless driver.\n" \
		"\t-i\t Install rtl8187 kernel wireless.\n" \
		"\t-u\t Uninstall rtl8187 kernel wireless.\n"
}

if [[ $# -eq 0 ]]; then
	usage
	exit 1
fi

while getopts ":cbiu" opt; do
	case $opt in
		c)
			CLEAN=1
			;;
		b)
			BUILD=1
			;;
		i)
			INSTALL=1
			;;
		u)
			UNINSTALL=1
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			;;
		*)
			usage
			exit 0
			;;
	esac
done

if [[ (${INSTALL} -eq 1 && ${UNINSTALL} -eq 1) ||
    	(${BUILD} -eq 1  && ${UNINSTALL} -eq 1) ]]; then
	echo "! Invalid arguments."
	usage
	exit 1
fi

if [[ ${CLEAN} -eq 1 ]]; then
	rm -rf tmp backports.tar.xz
fi

if [[ ${BUILD} -eq 1 ]]; then

	rm -rf tmp

	if [[ ! -f "backports.tar.xz" ]]; then
		if ! wget -c ${BACKPORTS_URL} -O backports.tar.xz; then
			echo "! Failed to download backports ..."
			exit 1
		fi
	fi

	if [[ ! -f ${MATRIX_RTL8187_PATCH} ]]; then
		if ! wget ${MATRIX_PATCH_URL} -O rtl8187-matrix.patch; then
			echo "! Failed to download rtl8187 matrix patch ..."
			exit 1
		fi
	fi

	if [[ ! -f ${KALI_INJECTION_PATCH} ]]; then
		if ! wget "${INJECTION_PATCH_URL}" -O kali-wifi-injection.patch; then
			echo "! Failed to download wifi injection kali patch ..."
			exit 1
		fi
	fi

	mkdir -p tmp/backports
	if ! tar xJf backports.tar.xz -C tmp/backports --strip-components=1; then
		echo "! Failed to extrack backports ..."
		rm -rf backports.tar.xz
		exit 1
	fi

	# Fix: GEN shipped-certs.c (make)
    if ! (sed -i \
        "s|cat $^|cat ${PWD}/tmp/backports/net/wireless/certs/sforshee.hex|g" \
        tmp/backports/net/wireless/Makefile); then

        echo "! Failed to apply wireless Makefile fix."
        exit 1
    fi

	if ! (cd tmp/backports && \
		patch -p1 --dry-run < "${MATRIX_RTL8187_PATCH}" && \
		patch -p1 < "${MATRIX_RTL8187_PATCH}" && \
		patch -p1 --dry-run < "${KALI_INJECTION_PATCH}" && \
		patch -p1 < "${KALI_INJECTION_PATCH}" && \
		make defconfig-rtl8187 && make); then

		echo "! Failed to build rtl8187 wireless driver."
		exit 1
	fi

	echo -e "\n>> " \
	    "Kernel have been built correctly for backports wireless drivers.\n" \
		"   Run ./build.sh -i to install rtl8187 wireless driver.\n\n"
fi

if [[ ${INSTALL} -eq 1 ]]; then

	if [[ ! -d "tmp/backports" ]]; then
		echo "! Failed to install rtl8187 wireless driver :" \
			" build dir not found."
		exit 1
	fi

	if ! (cd tmp/backports && sudo make modules_install); then
		echo "! Failed to install rtl8187 wireless driver."
		exit 1
	fi

	echo -e "\n>> " \
	    "Backports wireless drivers have been installed correctly.\n" \
		"   If you want skip reboot please remove the following modules " \
		"(and also those who use them) : mac80211 cfg80211\n" \
		"   If everything is ok you can replug your external wireless " \
		"device to load the new rtl8187 driver.\n\n"
fi

if [[ ${UNINSTALL} -eq 1 ]]; then

	if [[ ! -d "tmp/backports" ]]; then
		echo "! Failed to uninstall rtl8187 wireless driver :" \
			" build dir not found."
		exit 1
	fi

	if ! (cd tmp/backports && sudo make uninstall); then
		echo "! Failed to uninstall rtl8187 wireless driver."
		exit 1
	fi

	echo -e "\n>> " \
		"Backports wireless drivers have been uninstalled correctly.\n" \
		"   If you want skip reboot please remove the following modules" \
		"(and also those who use them) : mac80211 cfg80211\n" \
		"   If everything is ok you can replug your external wireless" \
		"device to load the old rtl8187 driver.\n\n"
fi
