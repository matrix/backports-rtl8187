#!/bin/bash
#
# ~matrix

MATRIX_RTL8187_PATCH="${PWD}/rtl8187-matrix.patch"
KALI_INJECTION_PATCH="${PWD}/kali-wifi-injection.patch"

CLEAN=0
BUILD=0
INSTALL=0
UNINSTALL=0

function usage()
{
	echo -e "> Usage $0 <options>\n\noptions:\n" \
		"\t-c\t Cleanup workdir.\n" \
		"\t-b\t Build rtl8187 kernel wireless driver.\n" \
		"\t-i\t Install rtl8187 kernel wireless.\n" \
		"\t-u\t Uninstall rtl8187 kernel wireless.\n"
}

if [ $# -eq 0 ]; then
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

if ([ ${INSTALL} -eq 1 ] && [ ${UNINSTALL} -eq 1 ]) ||
   ([ ${BUILD} -eq 1 ] && [ ${UNINSTALL} -eq 1 ]); then
	echo "! Invalid arguments."
	usage
	exit 1
fi

if [ ${CLEAN} -eq 1 ]; then
	rm -rf tmp backports.tar.xz
fi

if [ ${BUILD} -eq 1 ]; then

	rm -rf tmp

	if [ ! -f "backports.tar.xz" ]; then
		wget -c https://cdn.kernel.org/pub/linux/kernel/projects/backports/stable/v5.10-rc6/backports-5.10-rc6-1.tar.xz -O backports.tar.xz
		if [ $? -ne 0 ]; then
			echo "! Failed to download backports ..."
			exit 1
		fi
	fi

	if [ ! -f "${MATRIX_RTL8187_PATCH}" ]; then
		wget https://raw.githubusercontent.com/matrix/backports-rtl8187/master/rtl8187-matrix.patch -O rtl8187-matrix.patch
		if [ $? -ne 0 ]; then
			echo "! Failed to download rtl8187 matrix patch ..."
			exit 1
		fi
	fi

	if [ ! -f "${KALI_INJECTION_PATCH}" ]; then
		wget 'https://gitlab.com/kalilinux/packages/linux/raw/kali/master/debian/patches/features/all/kali-wifi-injection.patch?inline=false' -O kali-wifi-injection.patch
		if [ $? -ne 0 ]; then
			echo "! Failed to download wifi injection kali patch ..."
			exit 1
		fi
	fi

	mkdir -p tmp/backports
	tar xJf backports.tar.xz -C tmp/backports --strip-components=1
	if [ $? -ne 0 ]; then
		echo "! Failed to extrack backports ..."
		rm -rf backports.tar.xz
		exit 1
	fi

	cd tmp/backports && \
		patch -p1 --dry-run < ${MATRIX_RTL8187_PATCH} && patch -p1 < ${MATRIX_RTL8187_PATCH} && \
		patch -p1 --dry-run < ${KALI_INJECTION_PATCH} && patch -p1 < ${KALI_INJECTION_PATCH} && \
		make defconfig-rtl8187 && make && cd - &> /dev/null

	if [ $? -ne 0 ]; then
		echo "! Failed to build rtl8187 wireless driver."
		exit 1
	fi

	cd ..
fi

if [ ${INSTALL} -eq 1 ]; then

	if [ ! -d "tmp/backports" ]; then
		echo "! Failed to install rtl8187 wireless driver : build dir not found."
		exit 1
	fi

	cd tmp/backports && sudo make modules_install

	if [ $? -ne 0 ]; then
		echo "! Failed to install rtl8187 wireless driver."
		exit 1
	fi

	cd - &> /dev/null

	echo -e "\n>> Backports wireless drivers have been installed correctly.\n" \
		"  If you want skip reboot please remove the following modules (and also those who use them) : mac80211 cfg80211\n" \
		"  If everything is ok you can replug your external wireless device to load the new rtl8187 driver.\n\n"
fi

if [ ${UNINSTALL} -eq 1 ]; then

	if [ ! -d "tmp/backports" ]; then
		echo "! Failed to uninstall rtl8187 wireless driver : build dir not found."
		exit 1
	fi

	cd tmp/backports && sudo make uninstall

	if [ $? -ne 0 ]; then
		echo "! Failed to uninstall rtl8187 wireless driver."
		exit 1
	fi

	cd - &> /dev/null

	echo -e "\n>> Backports wireless drivers have been uninstalled correctly.\n" \
		"  If you want skip reboot please remove the following modules (and also those who use them) : mac80211 cfg80211\n" \
		"  If everything is ok you can replug your external wireless device to load the old rtl8187 driver.\n\n"
fi
