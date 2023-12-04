#!/system/bin/sh
#
# its me zyarexx
# SPDX-License-Identifier: GPL-3.0-or-later
#
GetBusyBox="none"
sleep 1s
for i in  /system/xbin /system/bin /sbin /su/xbin /data/adb/modules/busybox-ndk/system/xbin /data/adb/modules_update/busybox-ndk/system/xbin /data/adb/modules/busybox-ndk/system/bin /data/adb/modules_update/busybox-ndk/system/bin /data/adb/ksu/bin /data/adb/magisk
do
    if [[ "$GetBusyBox" == "none" ]]; then
        if [[ -f $i/busybox ]]; then
            GetBusyBox=$i/busybox
        fi
    fi
done

if [[ "$GetBusyBox" == "none" ]];then
    GetBusyBox=""
fi
