#!/bin/sh -e
#
# Copyright (c) 2009-2014 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

SYST=$(uname -n)
time=$(date +%Y-%m-%d)

DIR=$PWD
if [ ! -d ${DIR}/ignore ] ; then
	mkdir -p ${DIR}/ignore
fi
tempdir=$(mktemp -d -p ${DIR}/ignore)

if [ -f ${DIR}/config ] ; then
	. ${DIR}/config
fi

image_type="lxde"
wheezy_release="7.3"

bborg_pkg_list=""

#Development tools:
bborg_pkg_list="${bborg_pkg_list} autoconf automake1.9 build-essential bison device-tree-compiler libtool less flex g++ gdb pkg-config"

#Node libs:
bborg_pkg_list="${bborg_pkg_list} libc-ares-dev"

#Cloud9 libs:
bborg_pkg_list="${bborg_pkg_list} curl libssl-dev apache2-utils libxml2-dev"

#xorg:
bborg_pkg_list="${bborg_pkg_list} xserver-xorg-video-modesetting xserver-xorg x11-xserver-utils xinput"

#lxde:
bborg_pkg_list="${bborg_pkg_list} lxde-core lightdm leafpad alsa-utils evtest screen"

#lxde wifi:
bborg_pkg_list="${bborg_pkg_list} wicd-gtk"

#lxde wifi:
#bborg_pkg_list="${bborg_pkg_list} connman"

#development libs:
bborg_pkg_list="${bborg_pkg_list} python-opencv libsdl1.2-dev"

#Web Stuff:
bborg_pkg_list="${bborg_pkg_list} xchat"

#Chromium libs:
bborg_pkg_list="${bborg_pkg_list} libxss1 libnss3 libxslt1.1 libspeechd2"

minimal_armel () {
	rm -f "${DIR}/.project" || true

	#Actual Releases will use version numbers..
	case "${release}" in
	wheezy)
		#http://www.debian.org/releases/wheezy/
		export_filename="${distro}-${wheezy_release}-${image_type}-${dpkg_arch}-${time}"
		;;
	quantal)
		export_filename="${distro}-12.10-${image_type}-${dpkg_arch}-${time}"
		;;
	raring)
		export_filename="${distro}-13.04-${image_type}-${dpkg_arch}-${time}"
		;;
	saucy)
		export_filename="${distro}-13.10-${image_type}-${dpkg_arch}-${time}"
		;;
	*)
		export_filename="${distro}-${release}-${image_type}-${dpkg_arch}-${time}"
		;;
	esac

	#When doing offical releases, always hard lock the kernel version...
	#chroot_KERNEL_HTTP_DIR="http://rcn-ee.net/deb/${release}-${dpkg_arch}/v3.8.13-bone36/"

	tempdir=$(mktemp -d -p ${DIR}/ignore)

	cat > ${DIR}/.project <<-__EOF__
		tempdir="${tempdir}"
		export_filename="${export_filename}"

		distro="${distro}"
		release="${release}"
		dpkg_arch="${dpkg_arch}"
		time="${time}"

		deb_mirror="${deb_mirror}"
		deb_components="${deb_components}"

		apt_proxy="${apt_proxy}"

		include_pkgs_list="${include_pkgs_list}"
		exclude_pkgs_list="${exclude_pkgs_list}"
		base_pkg_list="${base_pkg_list}"

		image_hostname="${image_hostname}"

		user_name="${user_name}"
		full_name="${full_name}"
		password="${password}"

		include_firmware="${include_firmware}"

		chroot_very_small_image="${chroot_very_small_image}"
		chroot_generic_startup_scripts="${chroot_generic_startup_scripts}"
		chroot_ENABLE_DEB_SRC="${chroot_ENABLE_DEB_SRC}"
		chroot_KERNEL_HTTP_DIR="${chroot_KERNEL_HTTP_DIR}"

		chroot_enable_bborg_repo="${chroot_enable_bborg_repo}"

		chroot_COPY_SETUP_SDCARD="${chroot_COPY_SETUP_SDCARD}"

		chroot_hook="${chroot_hook}"
		chroot_script="${chroot_script}"
		chroot_uenv_txt="${chroot_uenv_txt}"

	__EOF__

	cat ${DIR}/.project

	/bin/sh -e "${DIR}/RootStock-NG.sh" || { exit 1 ; }
}

compression () {
	echo "Starting Compression"
	cd ${DIR}/deploy/

	tar cvf ${export_filename}.tar ./${export_filename}
	#xz -z -7 -v "${export_filename}.tar"
	cd ${DIR}/
}

production () {
	echo "Starting Production Stage"
	cd ${DIR}/deploy/

	cat > ${DIR}/deploy/gift_wrap_final_images.sh <<-__EOF__
	#!/bin/bash
	#This script's only purpose is to remember a mundane task from release to release for the release manager.

	if [ -d ./debian-${wheezy_release}-${image_type}-armhf-${time} ] ; then
		rm -rf debian-${wheezy_release}-${image_type}-armhf-${time} || true
	fi

	#user may run ./ship.sh twice...
	if [ ! -f debian-${wheezy_release}-${image_type}-armhf-${time}.tar.xz ] ; then
		xz -z -7 -v debian-${wheezy_release}-${image_type}-armhf-${time}.tar
	fi
	tar xf debian-${wheezy_release}-${image_type}-armhf-${time}.tar.xz

	if [ -f BBB-eMMC-flasher-debian-${wheezy_release}-${time}-2gb.img ] ; then
		rm BBB-eMMC-flasher-debian-${wheezy_release}-${time}-2gb.img || true
	fi

	if [ -f bone-debian-${wheezy_release}-${time}-4gb.img ] ; then
		rm bone-debian-${wheezy_release}-${time}-4gb.img || true
	fi

	cd debian-${wheezy_release}-${image_type}-armhf-${time}/
	sudo ./setup_sdcard.sh --img BBB-eMMC-flasher-debian-${wheezy_release}-${time} --uboot bone --beagleboard.org-production --bbb-flasher --enable-systemd
	sudo ./setup_sdcard.sh --img-4gb bone-debian-${wheezy_release}-${time} --uboot bone --beagleboard.org-production --enable-systemd

	mv *.img ../
	cd ..
	rm -rf debian-${wheezy_release}-${image_type}-armhf-${time}/ || true

	if [ -f BBB-eMMC-flasher-debian-${wheezy_release}-${time}-2gb.img.xz ] ; then
		rm BBB-eMMC-flasher-debian-${wheezy_release}-${time}-2gb.img.xz || true
	fi
	xz -z -7 -v BBB-eMMC-flasher-debian-${wheezy_release}-${time}-2gb.img

	if [ -f bone-debian-${wheezy_release}-${time}-4gb.img.xz ] ; then
		rm bone-debian-${wheezy_release}-${time}-4gb.img.xz || true
	fi
	xz -z -7 -v bone-debian-${wheezy_release}-${time}-4gb.img

	__EOF__

	chmod +x ${DIR}/deploy/gift_wrap_final_images.sh

	cd ${DIR}/
}

kernel_chooser () {
	if [ -f ${tempdir}/LATEST-${SUBARCH} ] ; then
		rm -rf ${tempdir}/LATEST-${SUBARCH} || true
	fi

	wget --no-verbose --directory-prefix=${tempdir}/ http://rcn-ee.net/deb/${release}-${dpkg_arch}/LATEST-${SUBARCH}
	FTP_DIR=$(cat ${tempdir}/LATEST-${SUBARCH} | grep "ABI:1 ${KERNEL_ABI}" | awk '{print $3}')
	FTP_DIR=$(echo ${FTP_DIR} | awk -F'/' '{print $6}')
}

select_rcn_ee_net_kernel () {
	SUBARCH="omap-psp"
	KERNEL_ABI="STABLE"
	kernel_chooser
	chroot_KERNEL_HTTP_DIR="${mirror}/${release}-${dpkg_arch}/${FTP_DIR}/"
}

pkg_list () {
	base_pkg_list=""
	if [ ! "x${no_pkgs}" = "xenable" ] ; then
		. ${DIR}/var/pkg_list.sh

		include_pkgs_list="git-core,initramfs-tools,locales,sudo,wget"

		if [ "x${include_firmware}" = "xenable" ] ; then
			base_pkg_list="${base_pkgs} ${extra_pkgs} ${bborg_pkg_list} ${firmware_pkgs}"
		else
			base_pkg_list="${base_pkgs} ${extra_pkgs} ${bborg_pkg_list}"
		fi
	fi
}

is_ubuntu () {
	image_hostname="beaglebone"
	distro="ubuntu"
	user_name="ubuntu"
	password="temppwd"
	full_name="Demo User"

	deb_mirror="ports.ubuntu.com/ubuntu-ports/"
	deb_components="main universe multiverse"

	pkg_list
}

is_debian () {
	image_hostname="beaglebone"
	distro="debian"
	user_name="debian"
	password="temppwd"
	full_name="Demo User"

	deb_mirror="ftp.us.debian.org/debian/"
	deb_components="main contrib non-free"

	pkg_list
	exclude_pkgs_list=""
#	chroot_very_small_image="enable"
}

#12.10
quantal_release () {
	extra_pkgs="devmem2"
	firmware_pkgs="linux-firmware"
	is_ubuntu
	release="quantal"
	select_rcn_ee_net_kernel
	minimal_armel
	compression
}

#13.04
raring_release () {
	extra_pkgs="devmem2"
	firmware_pkgs="linux-firmware"
	is_ubuntu
	release="raring"
	select_rcn_ee_net_kernel
	minimal_armel
	compression
}

#13.10
saucy_release () {
	extra_pkgs="devmem2"
	firmware_pkgs="linux-firmware"
	is_ubuntu
	release="saucy"
	select_rcn_ee_net_kernel
	minimal_armel
	compression
}

#14.04
trusty_release () {
	extra_pkgs="devmem2"
	firmware_pkgs="linux-firmware"
	is_ubuntu
	release="trusty"
	select_rcn_ee_net_kernel
	minimal_armel
	compression
}

wheezy_release () {
	extra_pkgs="systemd"
	firmware_pkgs="atmel-firmware firmware-ralink firmware-realtek libertas-firmware zd1211-firmware"
	is_debian
	release="wheezy"
	select_rcn_ee_net_kernel
	minimal_armel
	compression
}

jessie_release () {
	extra_pkgs="systemd"
	firmware_pkgs="atmel-firmware firmware-ralink firmware-realtek libertas-firmware zd1211-firmware"
	is_debian
	release="jessie"
	select_rcn_ee_net_kernel
	minimal_armel
	compression
}

sid_release () {
	extra_pkgs="systemd"
	firmware_pkgs="atmel-firmware firmware-ralink firmware-realtek libertas-firmware zd1211-firmware"
	is_debian
	release="sid"
	select_rcn_ee_net_kernel
	minimal_armel
	compression
}

if [ -f ${DIR}/releases.sh ] ; then
	. ${DIR}/releases.sh
fi

if [ ! "${apt_proxy}" ] ; then
	apt_proxy=""
fi
if [ ! "${mirror}" ] ; then
	mirror="http://rcn-ee.net/deb"
fi
if [ -f ${DIR}/rcn-ee.host ] ; then
	. ${DIR}/host/rcn-ee-host.sh
fi

mkdir -p ${DIR}/deploy/

#include gpl/source package...
chroot_ENABLE_DEB_SRC="enable"

chroot_COPY_SETUP_SDCARD="enable"

#FIXME: things to add to .config:
include_firmware="enable"
chroot_generic_startup_scripts="enable"
chroot_script="beagleboard.org.sh"
chroot_uenv_txt="beagleboard.org.txt"

chroot_enable_bborg_repo="enable"
#no_pkgs="enable"

dpkg_arch="armhf"
DEFAULT_RELEASES="wheezy"
for REL in ${RELEASES:-$DEFAULT_RELEASES} ; do
	${REL}_release
done
production

rm -rf ${tempdir} || true

echo "done"
