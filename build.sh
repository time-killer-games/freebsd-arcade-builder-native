#!/bin/sh
cd "${0%/*}"
set -e -u 

# Run script as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi

export cwd="`realpath | sed 's|/scripts||g'`"

. ${cwd}/conf/build.conf
. ${cwd}/conf/general.conf

cleanup(){
    umount ${release} || true
    umount ${release}/dev || true
    umount ${release}/var/cache/pkg/ || true
    mdconfig -d -u 0 || true
    rm -rf ${livecd}/pool.img || true
    rm -rf ${livecd} || true
}

setup(){
    # Make directories
    mkdir -pv ${livecd} ${base} ${iso} ${software} ${base} ${release} ${cdroot}

    # Create and mount pool
    truncate -s 6g ${livecd}/pool.img
    mdconfig -a -t vnode -f ${livecd}/pool.img -u 0
    zpool create freebsd /dev/md0
    zfs set mountpoint=${release} freebsd 
    zfs set compression=gzip-6 freebsd

    # UFS alternative code (just in case)
    # gpart create -s GPT md0
    # gpart add -t freebsd-ufs md0
    # bsdlabel -w md0 auto
    # newfs -U md0a
    # mount /dev/md0a ${release}
}

build(){
    # Base Preconfig
    mkdir -pv ${release}/etc
    
    # Add and extract base/kernel into ${release}
    cd ${base}
    # TODO: Switch with CoreNGS release
    fetch http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/13.0-RELEASE/base.txz
    fetch http://ftp.freebsd.org/pub/FreeBSD/releases/amd64/13.0-RELEASE/kernel.txz
    tar -zxvf base.txz -C ${release}
    tar -zxvf kernel.txz -C ${release}

    # Add base items
    touch ${release}/etc/fstab
    mkdir -pv ${release}/cdrom

    # Add packages
    cp /etc/resolv.conf ${release}/etc/resolv.conf
    mkdir -pv ${release}/var/cache/pkg
    mount_nullfs ${software} ${release}/var/cache/pkg
    mount -t devfs devfs ${release}/dev
    cat ${pkgdir}/${tag}.${desktop}.${platform} | xargs pkg -c ${release} install -y
    chroot ${release} pkg install -y pkg
    
    # Add software overlays 
    mkdir -pv ${release}/usr/local/general ${release}/usr/local/freebsd

    rm ${release}/etc/resolv.conf
    umount ${release}/var/cache/pkg

    # Move source files
    cp ${base}/base.txz ${release}/usr/local/freebsd/base.txz
    cp ${base}/kernel.txz ${release}/usr/local/freebsd/kernel.txz
    
    # rc
    . ${srcdir}/setuprc.sh
    setuprc

    # Other configs
    #mv ${release}/usr/local/etc/devd/automount_devd.conf ${release}/usr/local/etc/devd/automount_devd.conf.skip
    chroot ${release} touch /boot/entropy

    # Add desktop environment
    chroot ${release} pw mod user "root" -w none
    chroot ${release} chsh -s /bin/csh "root"
    mkdir -p ${release}/usr/local/etc/rc.d
    mkdir -p ${release}/usr/local/etc/X11/xorg.conf.d
    echo "/root/start.sh" > ${release}/root/.xinitrc
    echo "/usr/bin/su -l root -c \"/sbin/shutdown -p now\"" >> ${release}/root/.xinitrc
    chmod 777 ${release}/root/.xinitrc
    echo "RandomPlacement" > ${release}/root/.twmrc
    echo "BorderWidth=0" >> ${release}/root/.twmrc
    echo "NoTitle" >> ${release}/root/.twmrc
    echo "/root/start.sh" > ${release}/root/.xinitrc
    chmod 777 ${release}/root/.xinitrc
    cp -f "${0%/*}/src/login.sh" ${release}/usr/local/etc/rc.d/login.sh
    chmod 777 ${release}/usr/local/etc/rc.d/login.sh
    echo "kern.corefile=/dev/null" > ${release}/etc/sysctl.conf
    echo "kern.coredump=0" >> ${release}/etc/sysctl.conf
    echo "startx -- -nocursor" >> ${release}/root/.login
    chmod 777 ${release}/root/.login
    echo "twm -display :0 &" > ${release}/root/start.sh
    echo "sleep 5" >> ${release}/root/start.sh
    echo "/root/run" >> ${release}/root/start.sh
    echo "/sbin/shutdown -p now" >> ${release}/root/start.sh
    chmod 777 ${release}/root/start.sh
    echo "Section  \"Device\"" > ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "  Identifier  \"Card0\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "  Driver  \"scfb\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "EndSection" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "Section \"Monitor\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "  Identifier \"Monitor0\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "  HorizSync 30.0-62.0" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "  VertRefresh 50.0-70.0" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "EndSection" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "Section \"Screen\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "  Identifier \"Screen0\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "  Monitor \"Monitor0\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "  Device \"Card0\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "  DefaultDepth 24" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "  SubSection \"Display\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "    Depth 24" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "    Modes \"640x480\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "  EndSubSection" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "EndSection" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-uefi.conf
    echo "Section  \"Device\"" > ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "  Identifier  \"Card0\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "EndSection" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "Section \"Monitor\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "  Identifier \"Monitor0\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "  HorizSync 30.0-62.0" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "  VertRefresh 50.0-70.0" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "EndSection" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "Section \"Screen\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "  Identifier \"Screen0\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "  Monitor \"Monitor0\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "  Device \"Card0\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "  DefaultDepth 24" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "  SubSection \"Display\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "    Depth 24" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "    Modes \"640x480\"" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "  EndSubSection" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    echo "EndSection" >> ${release}/usr/local/etc/X11/xorg.conf.d/xorg-bios.conf
    fetch https://github.com/time-killer-games/potabi-experiment/releases/download/v1.0.0.0/run -o ${release}/root/run
    fetch https://github.com/time-killer-games/potabi-experiment/releases/download/v1.0.0.0/k2s -o ${release}/root/k2s
    fetch https://github.com/time-killer-games/potabi-experiment/releases/download/v1.0.0.0/fbm -o ${release}/root/fbm
    chmod 777 ${release}/root/run
    chmod 777 ${release}/root/k2s
    chmod 777 ${release}/root/fbm

    # Extra configuration (borrowed from GhostBSD builder)
    echo "gop set 0" >> ${release}/boot/loader.rc.local

    # This sucks, but it has to function like this if we don't want it to break all the time
    echo "Unmounting ${release}/dev - this could take up to 60 seconds"
    umount ${release}/dev || true
    timer=0
    while [ "$timer" -lt 5000000 ]; do
        timer=$(($timer+1))
    done
    umount -f ${release}/dev || true

    # Uzip Ramdisk and Boot code borrowed from GhostBSD
    # Uzips
    install -o root -g wheel -m 755 -d "${cdroot}"
    mkdir -pv "${cdroot}/data"
    zfs snapshot freebsd@clean
    zfs send -c -e freebsd@clean | dd of=/usr/local/freebsd-build/cdroot/data/system.img status=progress bs=1M

    # Ramdisk
    ramdisk_root="${cdroot}/data/ramdisk"
    mkdir -pv ${ramdisk_root}
    cd "${release}"
    tar -cf - rescue | tar -xf - -C "${ramdisk_root}"
    cd "${prjdir}"
    install -o root -g wheel -m 755 "${rmddir}/init.sh.in" "${ramdisk_root}/init.sh"
    sed "s/@VOLUME@/FREEBSD/" "${rmddir}/init.sh.in" > "${ramdisk_root}/init.sh"
    mkdir -pv "${ramdisk_root}/dev"
    mkdir -pv "${ramdisk_root}/etc"
    touch "${ramdisk_root}/etc/fstab"
    install -o root -g wheel -m 755 "${rmddir}/rc.in" "${ramdisk_root}/etc/rc"
    cp ${release}/etc/login.conf ${ramdisk_root}/etc/login.conf
    makefs -M 10m -b '10%' "${cdroot}/data/ramdisk.ufs" "${ramdisk_root}"
    gzip "${cdroot}/data/ramdisk.ufs"
    rm -rf "${ramdisk_root}"

    # Boot
    cd ${release}
    tar -cf - boot | tar -xf - -C ${cdroot}
    echo "Boot directory listed as: ${boodir}"
    echo "CDRoot directory listed as: ${cdroot}"
    cp -r ${boodir}/* ${cdroot}/boot/.
    mkdir -pv ${cdroot}/etc
    cd ${prjdir} && zpool export freebsd && while zpool status freebsd >/dev/null; do :; done 2>/dev/null
}

image(){
    cd ${prjdir}
    sh ${mkidir}/mkiso.${platform}.sh -b ${label} ${isopath} ${cdroot}
    cd ${iso}
    echo "Build completed"
    ls
}

cleanup
setup
build
image
