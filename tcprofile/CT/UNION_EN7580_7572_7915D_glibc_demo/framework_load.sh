#!/bin/sh

#Mount cgroups
cgroot="${1:-/sys/fs/cgroup}"
subsys="${2:-blkio cpu cpuacct cpuset devices freezer memory ns}"
/bin/mount -t tmpfs cgroup_root "${cgroot}"
for ss in $subsys; do
  /bin/mkdir -p "$cgroot/$ss"
  /bin/mount -t cgroup -o "$ss" "$ss" "$cgroot/$ss"
done

#Mount ubi system
/userfs/bin/ubiattach /dev/ubi_ctrl -m 10
/bin/mount -t ubifs ubi0:ubifs0 /opt/upt/apps
if [ "$?" != "0" ]; then
echo "mount ubi system failed!"
/userfs/bin/ubidetach /dev/ubi_ctrl -m 10
/userfs/bin/ubiformat /dev/mtd10 -y
/userfs/bin/ubiattach /dev/ubi_ctrl -m 10
/userfs/bin/ubimkvol /dev/ubi0 -s 110608KiB -N ubifs0
/bin/mount -t ubifs ubi0:ubifs0 /opt/upt/apps
/bin/mkdir -p /opt/upt/apps/etc/dbus-1
fi