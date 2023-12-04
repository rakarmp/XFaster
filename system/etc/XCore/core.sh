#!/system/bin/sh
#
# its me zyarexx
# SPDX-License-Identifier: GPL-3.0-or-later
#
for GetAllCmds in ${@}
do
    eval $GetAllCmds
done

. $ModulPath/system/etc/XCore/misc/get-bb.sh
. $ModulPath/system/etc/XCore/misc/initialize.sh
. $ModulPath/system/etc/XCore/misc/key.sh
. $ModulPath/system/etc/XCore/misc/funclist.sh

sync

while [[ "$MODULE_STATUS" == "1" ]]
do
    # always check module status
    RunModules="$(cat $PMConfig/status.conf)"
    if [[ "$RunModules" -ge "1" ]];then
        if [[ "$BOOTmode" == "1" ]];then
            . $MPATH/system/etc/XCore/main.sh "boot"
            BOOTmode="0"
        elif [[ "$BOOTmode" == "0" ]];then
            . $MPATH/system/etc/XCore/main.sh
        fi
    else
        for ngentod in last_fstrim.log last_optimize_database.log logs.log logs_error.log optimize_database.log write.log;do
            [[ "$(cat $MPATH/system/etc/XCore/info/$ngentod)" != *"status.conf value still 0"* ]] && echo "status.conf value still 0" > $MPATH/system/etc/XCore/info/$ngentod
        done
        sleep 10s
    fi
done
