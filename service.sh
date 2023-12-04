#!/system/bin/sh
#
# its me zyarexx
#
## waiting booting done

while [[ `getprop sys.boot_completed` -ne 1 ]] || [[ ! -d "/sdcard" ]] || [[ ! -d "/system/bin" ]] || [[ ! -f "/system/etc/XCore/info/modules_id.info" ]]
do
       sleep 1s
done

MODDIR=${0%/*}

GetBusyBox="none"
GetBusyBoxPath="none"
for i in /system/xbin /system/bin /sbin /su/xbin /data/adb/modules/busybox-ndk/system/xbin /data/adb/modules_update/busybox-ndk/system/xbin /data/adb/modules/busybox-ndk/system/bin /data/adb/modules_update/busybox-ndk/system/bin /data/adb/ksu/bin /data/adb/magisk; do
    if [[ "$GetBusyBox" == "none" ]]; then
        if [[ -f $i/busybox ]]; then
            GetBusyBox=$i/busybox
            GetBusyBoxPath="$1"
            break
        fi
    fi
done

[[ "$GetBusyBox" == "none" ]] && exit

if [[ "$GetBusyBox" == "/data/adb/ksu/bin" ]] && [[ "$GetBusyBox" == "/data/adb/magisk" ]];then
    ASH_STANDALONE=1
fi

MiD=""
GetMid(){
    if [[ -f /system/etc/XCore/info/modules_id.info ]];then
        if [[ -z "$MiD" ]];then
            MiD="$(cat /system/etc/XCore/info/modules_id.info)"
            ModulPath="$(cat /system/etc/XCore/info/magisk_path)/$MiD"
        fi
    fi
    [[ -z "$MiD" ]] && $GetBusyBox sleep 1s && GetMid
}
GetMid

TotalTime="30"

for GetTime in 5 5 5 5 1 1 1 1 1 1 1 1 1 1
do
    echo "modules will run after $TotalTime s" > $MODDIR/system/etc/XCore/info/logs.log
    echo "modules will run after $TotalTime s" > $MODDIR/system/etc/XCore/info/logs_error.log
    $GetBusyBox sleep ${GetTime}s
    TotalTime=$(($TotalTime-$GetTime))
done
LetsRunService(){
    local data="${1}"
    shift
    local ARGS="${@}"
    $GetBusyBox sh $data "$ARGS" &
}

LetsRunService $MODDIR/system/etc/XCore/core.sh "BOOTmode='1' ModulPath='$(cat /system/etc/XCore/info/magisk_path)/$MiD'"
if [[ -f $MODDIR/system/etc/XCore/misc/generate-fps.sh ]] && [[ "$(cat $MODDIR/system/etc/XCore/configs/get_fps_service.conf)" == "1" ]];then
    LetsRunService $MODDIR/system/etc/XCore/misc/generate-fps.sh
fi