[[ "$BOOTMODE" == "false" ]] && abort "please flash this from magisk app" 

GetBusyBox="none"
sleep 1s
for i in /system/bin /system/xbin /sbin /su/xbin /data/adb/modules/busybox-ndk/system/xbin /data/adb/modules_update/busybox-ndk/system/xbin /data/adb/modules_update/busybox-ndk/system/xbin $MODPATH/../busybox-ndk/system/bin /data/adb/modules_update/busybox-ndk/system/bin $MODPATH/../busybox-ndk/system/bin /data/adb/ksu/bin /data/adb/magisk
do
    if [[ "$GetBusyBox" == "none" ]]; then
        if [[ -f $i/busybox ]]; then
            GetBusyBox=$i/busybox
        fi
    fi
done

if [[ "$GetBusyBox" == "none" ]];then
    GetBusyBox=""
    abort "busybox not detected please flash busybox"
fi

set_perm_recursive $MODPATH 0 0 0755 0777

if [[ "$GetBusyBox" == *"xbin"* ]]; then
    bin=xbin
else
    bin=bin
    mkdir $MODPATH/system/bin
    cp -af $MODPATH/system/xbin/* $MODPATH/system/bin
    rm -rf xbin
fi


## remove some useless files
if [ -f  $MODPATH/.gitattributes ]; then
    rm -rf $MODPATH/.gitattributes
fi
if [ -f  $MODPATH/.gitignore ]; then
    rm -rf $MODPATH/.gitignore
fi
if [ -f  $MODPATH/README.md ]; then
    rm -rf $MODPATH/README.md
fi
if [ -f  $MODPATH/README-id.md ]; then
    rm -rf $MODPATH/README-id.md
fi
if [ -f  $MODPATH/system/etc/XCore/configs/backup/placeholder ]; then
    rm -rf $MODPATH/system/etc/XCore/configs/backup/placeholder
fi
if [ -f  $MODPATH/system/bin/placeholder ]; then
    rm -rf $MODPATH/system/bin/placeholder
fi
if [ -f  $MODPATH/system/xbin/placeholder ]; then
    rm -rf $MODPATH/system/xbin/placeholder
fi
if [ -f  $MODPATH/system/bin/sqlite3 ]; then
    rm -rf $MODPATH/system/bin/sqlite3
fi
if [ -f $MODPATH/util_functions.sh ]; then
    rm -rf $MODPATH/util_functions.sh
fi
if [ -f $MODPATH/system/etc/XCore/thermal-backup/placeholder ];then
    rm -rf $MODPATH/system/etc/XCore/thermal-backup/placeholder
fi
if [ -f $MODPATH/system/vendor/etc/placeholder ];then
    rm -rf $MODPATH/system/vendor/etc/placeholder
fi

ClearDF="y"
ClearDFP=""
if [[ -d /vendor/etc/device_features ]];then
    rm -rf $MODPATH/system/vendor/etc/device_features/placeholder
    for ListXml in $(ls /vendor/etc/device_features)
    do
        Check="$(cat /vendor/etc/device_features/$ListXml | grep support_power_mode)"
        if [[ ! -z "$Check" ]];then
            cp -af /vendor/etc/device_features/$ListXml $MODPATH/system/vendor/etc/device_features/$ListXml
            sed -i 's/<bool name="support_power_mode">false<\/bool>/<bool name="support_power_mode">true<\/bool>/' $MODPATH/system/vendor/etc/device_features/$ListXml
            ClearDF="n"
            ClearDFP="$ClearDFP /vendor/etc/device_features"
        fi
    done
    # rm -rf $MODPATH/system/product
    [[ "$ClearDF" == "y" ]] && rm -rf $MODPATH/system/vendor/etc/device_features
else
    rm -rf $MODPATH/system/vendor/etc/device_features
fi

if [[ -d /system/product/etc/device_features ]];then
    rm -rf $MODPATH/system/product/etc/device_features/placeholder
    # rm -rf $MODPATH/system/vendor/etc/device_features
    for ListXml in $(ls /system/product/etc/device_features)
    do
        Check="$(cat /system/product/etc/device_features/$ListXml | grep support_power_mode)"
        if [[ ! -z "$Check" ]];then
            cp -af /system/product/etc/device_features/$ListXml $MODPATH/system/product/etc/device_features/$ListXml
            sed -i 's/<bool name="support_power_mode">false<\/bool>/<bool name="support_power_mode">true<\/bool>/' $MODPATH/system/product/etc/device_features/$ListXml
            ClearDF="n"
            ClearDFP="$ClearDFP /system/product/etc/device_features"
        fi
    done
    [[ "$ClearDF" == "y" ]] && rm -rf $MODPATH/system/product
else
    rm -rf $MODPATH/system/product
fi

if [[ -d /system/etc/device_features ]];then
    rm -rf $MODPATH/system/etc/device_features/placeholder
    # rm -rf $MODPATH/system/vendor/etc/device_features
    for ListXml in $(ls /system/etc/device_features)
    do
        Check="$(cat /system/etc/device_features/$ListXml | grep support_power_mode)"
        if [[ ! -z "$Check" ]];then
            cp -af /system/etc/device_features/$ListXml $MODPATH/system/etc/device_features/$ListXml
            sed -i 's/<bool name="support_power_mode">false<\/bool>/<bool name="support_power_mode">true<\/bool>/' $MODPATH/system/etc/device_features/$ListXml
            ClearDF="n"
            ClearDFP="$ClearDFP /system/etc/device_features"
        fi
    done
    [[ "$ClearDF" == "y" ]] && rm -rf $MODPATH/system/etc/device_features
else
    rm -rf $MODPATH/system/etc/device_features
fi

if [[ "$ClearDF" == "n" ]];then
    ui_print "- enable powermode option on control center"
    ui_print "- path : $ClearDFP"
fi

## custom thermal blank remover
rm -rf $MODPATH/system/etc/XCore/thermal-backup
for ListThermal in thermal-arvr.conf thermal-map.conf thermal-nolimits.conf thermal-normal.conf thermal-phone.conf thermal-tgame.conf thermal-sgame.conf
do
    if [[ -f $MODPATH/system/vendor/etc/$ListThermal ]];then
        rm -rf $MODPATH/system/vendor/etc/$ListThermal
    fi 
done

## magisk and ksu path
if [[ -z "$MagiskBase" ]] && [[ -d /data/adb/ksu  ]];then
    MagiskBase="/data/adb"
fi
echo "$MagiskBase/modules" > $MODPATH/system/etc/XCore/info/magisk_path
OldModolPath="$MagiskBase/modules/X-Faster"

if [[ "$MODPATH" == *"modules_update"* ]] && [[ ! -z "$OldModolPath" ]];then
    ## copy system.prop
    [[ -f $OldModolPath/system.prop ]] && cp -af $OldModolPath/system.prop $MODPATH/system.prop && ui_print "- copying existed system.prop"

    ## copy all existing config files
    [[ -d $OldModolPath/system/etc/XCore/configs ]] && cp -af $OldModolPath/system/etc/XCore/configs/* $MODPATH/system/etc/XCore/configs && ui_print "- copying all existed config files done"
fi

if [[ -f $MODPATH/system/etc/XCore/configs/manual_game_list.conf ]];then
    for ListManualGame in $(cat $MODPATH/system/etc/XCore/configs/manual_game_list.conf.ori)
    do
        if [[ -z "$(cat $MODPATH/system/etc/XCore/configs/manual_game_list.conf | grep $ListManualGame)" ]];then
            sed -i "1a  ${ListManualGame}" $MODPATH/system/etc/XCore/configs/manual_game_list.conf 
        fi
    done
    rm -rf $MODPATH/system/etc/XCore/configs/manual_game_list.conf.ori
else
    cp -af $MODPATH/system/etc/XCore/configs/manual_game_list.conf.ori $MODPATH/system/etc/XCore/configs/manual_game_list.conf
    rm -rf $MODPATH/system/etc/XCore/configs/manual_game_list.conf.ori
fi

[[ -d "$MODPATH/system/etc/XCore/configs/backup" ]] && rm -rf $MODPATH/system/etc/XCore/configs/backup/*

### fix folder permission
set_perm_recursive $MODPATH                                         0 0     0755 0777
set_perm_recursive $MODPATH/system/bin                              0 2000  0755 0755
set_perm_recursive $MODPATH/system/xbin                             0 2000  0755 0755
set_perm_recursive $MODPATH/system/system_ext/bin                   0 2000  0755 0755
set_perm_recursive $MODPATH/system/vendor/bin                       0 2000  0755 0755 u:object_r:vendor_file:s0
set_perm_recursive $MODPATH/system/etc/XCore                     0 0     0755 0777
set_perm $MODPATH/system.prop                                       0 0     0644

## if busybox detected
if [[ "$bin" == "xbin" ]];then
    sed -i "s/system\/bin\/sh/system\/xbin\/sh/g" $MODPATH/service.sh
    sed -i "s/system\/bin\/sh/system\/xbin\/sh/g" $MODPATH/system/etc/XCore/core.sh
    sed -i "s/system\/bin\/sh/system\/xbin\/sh/g" $MODPATH/system/etc/XCore/main.sh
    sed -i "s/system\/bin\/sh/system\/xbin\/sh/g" $MODPATH/system/etc/XCore/misc/funclist.sh
    sed -i "s/system\/bin\/sh/system\/xbin\/sh/g" $MODPATH/system/etc/XCore/misc/initialize.sh
    sed -i "s/system\/bin\/sh/system\/xbin\/sh/g" $MODPATH/system/xbin/x_g
    sed -i "s/system\/bin\/sh/system\/xbin\/sh/g" $MODPATH/system/xbin/x_l
    sed -i "s/system\/bin\/sh/system\/xbin\/sh/g" $MODPATH/system/xbin/x_le
    sed -i "s/system\/bin\/sh/system\/xbin\/sh/g" $MODPATH/system/xbin/x_m
fi

## override setting
echo "1" > $MODPATH/system/etc/XCore/configs/show_error.conf
echo "1" > $MODPATH/system/etc/XCore/configs/write_info.conf
echo "1" > $MODPATH/system/etc/XCore/configs/status.conf

## busybox fix path xD
if [[ -d /data/adb/modules_update/busybox-ndk ]];then
    cp -af /data/adb/modules_update/busybox-ndk $MODPATH/../busybox-ndk
    rm -rf /data/adb/modules_update/busybox-ndk
fi