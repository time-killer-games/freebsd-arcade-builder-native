setuprc(){
    chroot ${release} touch /etc/rc.conf
    chroot ${release} sysrc hostname="freebsd"
    chroot ${release} sysrc dbus_enable="YES"
    chroot ${release} sysrc zfs_enable="YES"
    chroot ${release} sysrc moused_enable="YES"
    chroot ${release} sysrc dumpdev="NO"
}