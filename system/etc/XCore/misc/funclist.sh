#!/system/bin/sh
#
# is me zyarexx
# SPDX-License-Identifier: GPL-3.0-or-later
#
GetErrorMsg(){
    if [[ "$(cat $PMConfig/show_error.conf)" == "1" ]];then
        RLOGsE=$MPATH/system/etc/XCore/info/logs_error.log
        local ErrCode="$?"
        [[ "$ErrCode" != "0" ]] && echo "$( date +"%H:%M:%S") | error on function ${1} | Error Code $ErrCode" >>$RLOGsE
    else
        RLOGsE="/dev/null"
        if [[ -f $MPATH/system/etc/XCore/info/logs_error.log ]];then
            [[ "$(cat $MPATH/system/etc/XCore/info/logs_error.log)" != *"error logs disabled"* ]] && WriteOnly "error logs disabled" $MPATH/system/etc/XCore/info/logs_error.log
        else
            WriteOnly "error logs disabled" $MPATH/system/etc/XCore/info/logs_error.log
        fi
    fi
}

SendLogs(){
    echo "$( date +"%H:%M:%S") | ${1}" >>$LOGs
} 2>>$RLOGsE

SendWLogs(){
    if [[ "$(cat $PMConfig/write_info.conf)" == "1" ]];then
        if [[ "$(cat $PMConfig/write_info.conf)" == "disabled" ]];then
            echo "$( date +"%H:%M:%S") | ${1}" >$MPATH/system/etc/XCore/info/write.log
        else
            echo "$( date +"%H:%M:%S") | ${1}" >>$MPATH/system/etc/XCore/info/write.log
        fi
    else
        local TheTEXT="write logs disabled, please enable it first"
        [[ "$(cat $PMConfig/write_info.conf)" != *"$TheTEXT"* ]] && WriteOnly "$TheTEXT" $MPATH/system/etc/XCore/info/write.log
    fi
} 2>>$RLOGsE

BackupScheduler(){
    local SchedList=""
    local BlockSD
    for BlockSD in $(ls /sys/block | grep sd)
    do
        if [[ "${#BlockSD}" == "3" ]];then
            SchedList="${SchedList}$(cat /sys/block/$BlockSD/queue/scheduler | awk -F '[' '{print $2}' | awk -F ']' '{print $1}') "
        fi
    done
    [[ ! -z "$SchedList" ]] && WriteOnly "$SchedList" "$PMConfig/backup/sdx_scheduler"
    SchedList=""
    for BlockSD in $(ls /sys/block | grep mmcblk)
    do
        if [[ "${#BlockSD}" == "7" ]];then
            SchedList="${SchedList}$(cat /sys/block/$BlockSD/queue/scheduler | awk -F '[' '{print $2}' | awk -F ']' '{print $1}') "
        fi
    done
    [[ ! -z "$SchedList" ]] && WriteOnly "$SchedList" "$PMConfig/backup/mmcblkx_scheduler"
    GetErrorMsg "BackupScheduler"
} 2>>$RLOGsE

RestoreScheduler(){
    local TBNumber="1"
    local GetSchedVal=""
    local BlockSD
    for BlockSD in $(ls /sys/block | grep sd)
    do
        if [[ "${#BlockSD}" == "3" ]];then
            if [[ "$(cat $PMConfig/scheduler.lock.conf)" == "0" ]];then
                GetSchedVal="$(cat $PMConfig/backup/sdx_scheduler | awk -F ' ' '{print $'$TBNumber'}' )"
            else
                GetSchedVal="$(cat $PMConfig/scheduler.conf)"
            fi
            WriteTo "$GetSchedVal" /sys/block/${BlockSD}/queue/scheduler
            TBNumber=$(($TBNumber+1))
        fi
    done
    TBNumber="1"
    for BlockSD in $(ls /sys/block | grep mmcblk)
    do
        if [[ "${#BlockSD}" == "7" ]];then
            if [[ "$(cat $PMConfig/scheduler.lock.conf)" == "0" ]];then
                GetSchedVal="$(cat $PMConfig/backup/mmcblkx_scheduler | awk -F ' ' '{print $'$TBNumber'}' )"
            else
                GetSchedVal="$(cat $PMConfig/scheduler.conf)"
            fi
            WriteTo "$GetSchedVal" /sys/block/${BlockSD}/queue/scheduler
            TBNumber=$(($TBNumber+1))
        fi
    done
    GetErrorMsg "RestoreScheduler"
} 2>>$RLOGsE

SetScheduler(){
    local BlockSD
    if [[ "$(cat $PMConfig/scheduler.lock.conf)" == "0" ]];then
        local ChangeTo="noop"
        [[ ! -z "${1}" ]] && ChangeTo="${1}"
    else
        local ChangeTo="$(cat $PMConfig/scheduler.conf)"
    fi
    for BlockSD in $(ls /sys/block | grep sd)
    do
        if [[ "${#BlockSD}" == "3" ]];then
            WriteTo "$ChangeTo" "/sys/block/$BlockSD/queue/scheduler"
        fi
    done
    for BlockSD in $(ls /sys/block | grep mmcblk)
    do
        if [[ "${#BlockSD}" == "3" ]];then
            WriteTo "$ChangeTo" "/sys/block/$BlockSD/queue/scheduler"
        fi
    done
    GetErrorMsg "SetScheduler"
} 2>>$RLOGsE

BackupConfig(){
    DoBackup="n"
    local ListBackup
    for ListBackup in throttling force_no_nap force_bus_on force_clk_on force_rail_on bus_split
    do
        if [[ -f "$NyariGPU/${ListBackup}" ]]; then
            WriteOnly "$(cat $NyariGPU/${ListBackup})" "$PMConfig/backup/gpu_${ListBackup}"
            DoBackup="y"
        fi
    done
    [[ ! -f $PMConfig/backup/sdx_scheduler ]] && [[ -f /sys/block/sda/queue/scheduler ]] && BackupScheduler && DoBackup="y"
    [[ ! -f $PMConfig/backup/mmcblkx_scheduler ]] && [[ -f /sys/block/mmcblk0/queue/scheduler ]] && BackupScheduler && DoBackup="y"

    if [[ -f /proc/sys/kernel/sched_lib_name ]];then
        if [[ ! -z "$(cat /proc/sys/kernel/sched_lib_name)" ]];then
            WriteOnly "$(cat /proc/sys/kernel/sched_lib_name)" "$PMConfig/backup/sched_lib_name" 
            DoBackup="y"
            if [[ -z "$(cat $PMConfig/backup/sched_lib_name)" ]];then
                WriteOnly "UnityMain,libunity.so" "$PMConfig/backup/sched_lib_name"
            fi
        else
            WriteOnly "UnityMain,libunity.so" "$PMConfig/backup/sched_lib_name"
        fi
    fi
    if [[ -f /proc/sys/kernel/sched_lib_mask_force ]];then
        if [[ ! -z "$(cat /proc/sys/kernel/sched_lib_mask_force)" ]];then
            WriteOnly "$(cat /proc/sys/kernel/sched_lib_mask_force)" "$PMConfig/backup/sched_lib_mask_force" 
            DoBackup="y"
            if [[ "$(cat $PMConfig/backup/sched_lib_mask_force)" == "0" ]];then
                WriteOnly "255" "$PMConfig/backup/sched_lib_mask_force"
            fi
        else
            WriteOnly "255" "$PMConfig/backup/sched_lib_mask_force"
        fi
    fi
    [[ "$DoBackup" == "y" ]] && SendLogs "backup config done . . ."
    GetErrorMsg "BackupConfig"
} 2>>$RLOGsE

SetOn(){
    local ListTweaked
    local NoLogs="n"
    [[ ! -z "${1}" ]] && [[ "${1}" == "silent" ]] && NoLogs="y"
    if [ -f $NyariGPU/devfreq/adrenoboost ]; then
        WriteOnly "4" "$NyariGPU/devfreq/adrenoboost"
        if [ "$(cat $NyariGPU/devfreq/adrenoboost)" != "4" ]; then
            WriteOnly "3" "$NyariGPU/devfreq/adrenoboost"
        fi
    fi
    for ListTweaked in throttling force_no_nap force_bus_on force_clk_on force_rail_on
    do
        if [ -f "$NyariGPU/$ListTweaked" ]; then
            WriteOnly "0" "$NyariGPU/$ListTweaked"
        fi
    done
    if [ -f "$NyariGPU/bus_split" ]; then
        WriteOnly "1" "$NyariGPU/bus_split"
    fi
    SetScheduler

    if [[ -f /sys/class/thermal/thermal_message/sconfig ]] && [[ "$(cat /sys/class/thermal/thermal_message/sconfig)" != "$(cat $PMConfig/sconfig.thermal.conf)" ]] && [[ "$(cat $PMConfig/sconfig.thermal.conf)" != "stock" ]];then
        WriteLockTo "$(cat $PMConfig/sconfig.thermal.conf)" /sys/class/thermal/thermal_message/sconfig
    fi

    ## MTK TWEAK ?
    Setppm enabled 1
    Setppm policy_status "1 0"
    Setppm policy_status "2 1"
    Setppm policy_status "3 0"
    Setppm policy_status "4 0"
    Setppm policy_status "5 0"
    Setppm policy_status "7 1"
    Setppm policy_status "9 1"

    SetGedParam gx_3D_benchmark_on "1"
    SetGedParam gx_force_cpu_boost "1"
    SetGedParam gx_game_mode "1"
    
    if [[ "$(cat $PMConfig/sconfig.thermal.conf)" == "-1" ]];then
        SetCpuAllOnline
        ThermalService "disable"
    fi

    SetGpuLimit 0

    if [[ "$NoLogs" == "n" ]];then
        getAppName=""
        local GetAllApps
        for GetAllApps in $(cat $PMConfig/game_list.conf)
        do
            if [[ "${GetAllApps}" == *"---->>"* ]] || [[ "${GetAllApps}" == *"<<----"* ]] || [[ "${GetAllApps}" == *"List-game-installed-start"* ]] || [[ "${GetAllApps}" == *"List-game-installed-end"* ]];then
                getAppName="${getAppName}"
            else
                if [[ ! -z "${getAppName}" ]];then
                    getAppName="${getAppName},"
                fi
                getAppName="${getAppName}${GetAllApps}"
            fi
        done
        if [[ "$getAppName" != *"$AppName"* ]] && [[ "$ModuleMode" != "Force On" ]];then
            if [[ ! -z "${getAppName}" ]];then
                getAppName="${getAppName},"
            fi
            getAppName="${getAppName}${AppName}"
        fi
        if [[ -f "/proc/sys/kernel/sched_lib_name" ]];then
            WriteOnly "$getAppName,UnityMain,libunity.so" "/proc/sys/kernel/sched_lib_name"
        fi
        if [[ -f "/proc/sys/kernel/sched_lib_mask_force" ]];then
            WriteOnly "255" "/proc/sys/kernel/sched_lib_mask_force"
        fi
    fi

    if [[ -f /sys/devices/system/cpu/sched/sched_boost ]];then
        local GetBefore="$(cat /sys/devices/system/cpu/sched/sched_boost)"
        WriteOnly "2" /sys/devices/system/cpu/sched/sched_boost
        [[ "$(cat /sys/devices/system/cpu/sched/sched_boost)" == "$GetBefore" ]] && WriteOnly "1" /sys/devices/system/cpu/sched/sched_boost
    fi

    [[ -f /proc/sys/kernel/sched_boost ]] && WriteOnly "1" /proc/sys/kernel/sched_boost

    [[ -f /sys/module/zyc_gpu/parameters/kgsl_old_check_gpuaddr ]] && WriteOnly "Y" /sys/module/zyc_gpu/parameters/kgsl_old_check_gpuaddr
    [[ -f /sys/module/zyc_gpu/parameters/kgsl_old_close ]] && WriteOnly "Y" /sys/module/zyc_gpu/parameters/kgsl_old_close
    [[ -f /sys/module/zyc_gpu/parameters/kgsl_thermal_limit ]] && WriteOnly "N" /sys/module/zyc_gpu/parameters/kgsl_thermal_limit

    [[ -f /sys/module/cpu_boost/parameters/input_boost_ms ]] && WriteOnly "120" /sys/module/cpu_boost/parameters/input_boost_ms

    [[ "$NoLogs" == "n" ]] && SendLogs "Module Tweak: Enabled"
    [[ "$NoLogs" == "n" ]] && SendLogs "When Use App: $AppName"
    WriteOnly "2" $PMConfig/status.conf
    GetErrorMsg "SetOn"
} 2>>$RLOGsE

SetOff(){
    local ListTweaked
    local NoLogs="n"
    [[ ! -z "${1}" ]] && [[ "${1}" == "silent" ]] && NoLogs="y"
    if [ -f $NyariGPU/devfreq/adrenoboost ]; then
        WriteOnly "0" $NyariGPU/devfreq/adrenoboost
    fi
    for ListTweaked in throttling force_no_nap force_bus_on force_clk_on force_rail_on bus_split
    do
        if [ -f "$NyariGPU/$ListTweaked" ] && [ -f "$PMConfig/backup/$ListTweaked" ]; then
            WriteOnly $(cat $PMConfig/backup/gpu_$ListTweaked) "$NyariGPU/$ListTweaked"
        fi
    done
    RestoreScheduler

    if [[ -f /sys/class/thermal/thermal_message/sconfig ]] && [[ "$(cat $PMConfig/sconfig.thermal.conf)" != "stock" ]];then
        if [[ "$(cat $PMConfig/sconfig.thermal.lock.conf)" == "1" ]];then
            WriteLockTo "$($PMConfig/sconfig.thermal.conf)" /sys/class/thermal/thermal_message/sconfig
        else
            WriteTo "0" /sys/class/thermal/thermal_message/sconfig
            ThermalService "enable"
        fi
    fi

    ## MTK TWEAK ?
    Setppm enabled 1
    Setppm policy_status "1 0"
	Setppm policy_status "2 0"
	Setppm policy_status "3 0"
	Setppm policy_status "4 1"
	Setppm policy_status "5 0"
	Setppm policy_status "7 1"
	Setppm policy_status "9 0"

    SetGedParam gx_3D_benchmark_on "0"
    SetGedParam gx_force_cpu_boost "0"
    SetGedParam gx_game_mode "0"

    SetGpuLimit 1

    if [[ -f "/proc/sys/kernel/sched_lib_name" ]];then
        WriteOnly "$(cat $PMConfig/backup/sched_lib_name)" "/proc/sys/kernel/sched_lib_name"
    fi
    if [[ -f "/proc/sys/kernel/sched_lib_mask_force" ]];then
        WriteOnly "$(cat $PMConfig/backup/sched_lib_mask_force)" "/proc/sys/kernel/sched_lib_mask_force"
    fi

    [[ -f /sys/devices/system/cpu/sched/sched_boost ]] && WriteOnly "0" /sys/devices/system/cpu/sched/sched_boost

    [[ -f /proc/sys/kernel/sched_boost ]] && WriteOnly "0" /proc/sys/kernel/sched_boost

    [[ "$NoLogs" == "n" ]] && SendLogs "Module Tweak: Disabled"
    WriteOnly "1" $PMConfig/status.conf

    [[ -f /sys/module/zyc_gpu/parameters/kgsl_old_check_gpuaddr ]] && WriteOnly "N" /sys/module/zyc_gpu/parameters/kgsl_old_check_gpuaddr
    [[ -f /sys/module/zyc_gpu/parameters/kgsl_old_close ]] && WriteOnly "N" /sys/module/zyc_gpu/parameters/kgsl_old_close
    [[ -f /sys/module/zyc_gpu/parameters/kgsl_thermal_limit ]] && WriteOnly "Y" /sys/module/zyc_gpu/parameters/kgsl_thermal_limit

    [[ -f /sys/module/cpu_boost/parameters/input_boost_ms ]] && WriteOnly "0" /sys/module/cpu_boost/parameters/input_boost_ms

    GetErrorMsg "SetOff"
} 2>>$RLOGsE

ThermalService(){
    local Getmode="${1}"
    if [[ $Getmode == "enable" ]] && [[ "$ThermalServiceStatus" == "N" ]];then
        for TL in $(ls /vendor/bin | grep thermal)
        do
        start $TL 2>/dev/null &
        SendLogs "thermal $TL started back"
        done
        ThermalServiceStatus="Y"
    elif [[ $Getmode == "disable" ]] && [[ "$ThermalServiceStatus" == "Y" ]];then
        for TL in $(ls /vendor/bin | grep thermal)
        do
        stop $TL 2>/dev/null
        SendLogs "thermal $TL stopped"
        done
        ThermalServiceStatus="N"
    fi
    GetErrorMsg "SetOff"
} 2>>$RLOGsE

SetSELINUX(){
    if [[ "${1}" == "change" ]];then
        if [ "$(getenforce)" == "Enforcing" ]; then
            changeSE="ya"
            setenforce 0
        fi
    fi
    if [[ "${1}" == "restore" ]];then
        if [[ ! -z "$changeSE" ]] && [[ "$changeSE" == "ya" ]];then
            changeSE=""
            setenforce 1
        fi
    fi
} 2>>$RLOGsE

GetStatusGpu(){
    if [ -f $NyariGPU/gpu_busy_percentage ]; then
        GetGpuStatus=$(cat "$NyariGPU/gpu_busy_percentage")
    else
        GetGpuStatus="0"
    fi
    if [ -f $NyariGPU/mem_pool_max_size ] && [ -f $NyariGPU/mem_pool_size ] && [ "$MALIGPU" == "YES" ]; then
        MemPollSizeMax=$(cat $NyariGPU/mem_pool_max_size)
        MemPollSize=$(cat $NyariGPU/mem_pool_size)
        GetGpuStatus="$(awk "BEGIN {print (100/$MemPollSizeMax)*$MemPollSize}" | awk -F "\\." '{print $1}')"
    fi
    GpuStatus="$( echo $GetGpuStatus | awk -F'%' '{sub(/^te/,"",$1); print $1 }' )"
    GpuStatus="${GpuStatus/" "/""}"
    GetErrorMsg "GetStatusGpu"
} 2>>$RLOGsE

GetActiveAppName(){
    AppName="$(dumpsys activity recents | grep 'Recent #0' | awk -F 'A=' '{ print $2 }' | awk -F ' ' '{ print $1 }')"
    if [[ "$AppName" == *":"* ]] ;then
        AppName="$(echo "$AppName" | awk -F ':' '{ print $2 }')"
    fi
    if [[ "$AppName" == *"apex "* ]] ;then
        AppName=""
    fi
    GetErrorMsg "GetActiveAppName"

} 2>>$RLOGsE

CheckCurrentApp(){
    [[ ! -f $PMConfig/game_list.conf ]] && RegenGameList
    local GameList="$(cat $PMConfig/game_list.conf)"
    local GetListGame
    GameDetected="n"
    if [[ "$GameList" == *"---->> List-game-installed-start <<----"* ]];then
        if [[ "$GameList" == *"$AppName"* ]];then
            GameDetected="y"
        fi
    else
        for GetListGame in $(cat $PMConfig/game_list.conf)
        do
            if [[ "$AppName" == *"$GetListGame"* ]];then
                GameDetected="y"
            fi
        done
    fi
    GetErrorMsg "CheckCurrentApp"
} 2>>$RLOGsE

RegenGameList(){
    [[ ! -f $PMConfig/manual_game_list.conf ]] && CheckFileConfig
    local GameList=$PMConfig/game_list.conf
    local ListGame
    local GetGameId
    echo "---->> List-game-installed-start <<----" > $GameList
    echo "<<---- List-game-installed-end ---->>" >> $GameList
    for ListGame in $(cat $PMConfig/manual_game_list.conf)
    do
        for GetGameId in $(pm list packages -3 | grep "${ListGame}" | awk -F= '{sub("package:","");print $1}')
        do
            if [[ "$( cat $GameList )" == *"$GetGameId"* ]]; then
                sed -i "1a  $GetGameId" $GameList
            fi
        done
    done
    if [[ "$(wc -l <$PMConfig/game_list.conf)" == "2" ]];then
        cp -af $PMConfig/manual_game_list.conf $PMConfig/game_list.conf
    fi
    GetErrorMsg "RegenGameList"
} 2>>$RLOGsE

SetGedParam(){
    [[ -d /sys/module/ged/parameters ]] && [[ -f /sys/module/ged/parameters/${1} ]] && WriteOnly "${2}" /sys/module/ged/parameters/${1}
    GetErrorMsg "SetGedParam"
} 2>>$RLOGsE

Setppm(){
    # [0] PPM_POLICY_PTPOD: enabled
    # [1] PPM_POLICY_UT: enabled
    # [3] PPM_POLICY_FORCE_LIMIT: enabled
    # [2] PPM_POLICY_SYS_BOOST: enabled
    # [4] PPM_POLICY_PWR_THRO: enabled
    # [5] PPM_POLICY_THERMAL: enabled
    # [7] PPM_POLICY_HARD_USER_LIMIT: enabled
    # [8] PPM_POLICY_USER_LIMIT: enabled
    # [9] PPM_POLICY_LCM_OFF: disabled
    # Usage: echo <idx> <1/0> > /proc/ppm/policy_status
    [[ -d /proc/ppm ]] && [[ -f /proc/ppm/${1} ]] && WriteOnly "${2}" /proc/ppm/${1}
    GetErrorMsg "Setppm"
} 2>>$RLOGsE

SetCpuAllOnline(){
    local i
    for i in 0 1 2 3 4 5 6 7
    do
        [[ -f /sys/devices/system/cpu/cpu$i/online ]] && WriteTo 1 /sys/devices/system/cpu/cpu$i/online
    done
    GetErrorMsg "SetCpuAllOnline"
} 2>>$RLOGsE

SetGpuLimit(){
    # echo [id][up_enable][low_enable] > /proc/gpufreq/gpufreq_limit_table
    # ex: echo 3 0 0 > /proc/gpufreq/gpufreq_limit_table
    # means disable THERMAL upper_limit_idx & lower_limit_idx
    #
    #        [name]  [id]     [prio]   [up_idx] [up_enable]  [low_idx] [low_enable]
    #        STRESS     0          8         -1          0         -1          0
    #          PROC     1          7         34          0         34          0
    #         PTPOD     2          6         -1          0         -1          0
    #       THERMAL     3          5         -1          0         -1          0
    #       BATT_OC     4          5         -1          0         -1          0
    #      BATT_LOW     5          5         -1          0         -1          0
    #  BATT_PERCENT     6          5         -1          0         -1          0
    #           PBM     7          5         -1          0         -1          0
    #        POLICY     8          4         -1          0         -1          0
    if [[ -f /proc/gpufreq/gpufreq_limit_table ]];then
        limited="${1}"
        local i
        for i in 0 1 2 3 4 5 6 7 8
        do
            # echo $i $limited $limited
            WriteOnly "$i $limited $limited" "/proc/gpufreq/gpufreq_limit_table"
        done
    fi
    GetErrorMsg "SetGpuLimit"
} 2>>$RLOGsE

UpdateFastCharging(){
    if [[ -f /sys/kernel/fast_charge/force_fast_charge ]];then
        SendLogs "Kernel Supported Fastcharging, enabling it"
        WriteOnly 2 /sys/kernel/fast_charge/force_fast_charge
        [[ "$(cat /sys/kernel/fast_charge/force_fast_charge)" == "0" ]] && WriteOnly 1 /sys/kernel/fast_charge/force_fast_charge
    fi
    GetErrorMsg "UpdateFastCharging"
} 2>>$RLOGsE

DoFstrim(){
    GetFstrim="$(cat $MPATH/system/etc/XCore/info/last_fstrim.log)"
    if [[ "$GetFstrim" != "$( date +"%Y-%m-%d" )" ]];then
        if [[ "$GetBusyBox" != "none" ]];then
            fstrim -v /cache 1>>$LOGs
            fstrim -v /data 1>>$LOGs
            fstrim -v /system 1>>$LOGs
            SendLogs "fstrim data cache & system done . . ."
        else
            SendLogs "Cannot do fstrim, because busybox not installed"
        fi
        WriteOnly "$( date +"%Y-%m-%d" )" $MPATH/system/etc/XCore/info/last_fstrim.log
    fi
    GetErrorMsg "DoFstrim"
} 2>>$RLOGsE

DoSqlite(){
    GetSqLite="$(cat $MPATH/system/etc/XCore/info/last_optimize_database.log)"
    if [[ "$GetSqLite" != "$( date +"%Y-%m-%d" )" ]];then
        if [[ "$GetBusyBox" != "none" ]];then
            local FilePath=""
            local ThrowInfo=""
            echo "$( date +"%H:%M:%S") | Start" > $MPATH/system/etc/XCore/info/optimize_database.log
            if [[ -d /data ]];then
                [[ -f /system/xbin/sqlite3 ]] && local SqLitePath=/system/xbin/sqlite3
                [[ -f /system/bin/sqlite3 ]] && local SqLitePath=/system/bin/sqlite3
                for FilePath in $(find /data -iname "*.db")
                do
                    ThrowInfo="n"
                    $SqLitePath $FilePath 'VACUUM;' 2>>/dev/null && ThrowInfo="y"
                    $SqLitePath $FilePath 'REINDEX;' 2>>/dev/null && ThrowInfo="y"
                    [[ "$ThrowInfo" == "y" ]] && echo "optimizing $FilePath" >> $MPATH/system/etc/XCore/info/optimize_database.log
                done
            fi
            echo "$( date +"%H:%M:%S") | End" >> $MPATH/system/etc/XCore/info/optimize_database.log
            SendLogs "optimze database done . . ."
        else
            echo "$( date +"%H:%M:%S") | Need Busybox for this things" > $MPATH/system/etc/XCore/info/optimize_database.log
            SendLogs "Cannot optimze database, because busybox not installed"
        fi
        WriteOnly "$( date +"%Y-%m-%d" )" $MPATH/system/etc/XCore/info/last_optimize_database.log
    fi
    GetErrorMsg "DoSqlite"
} 2>>$RLOGsE

MTKSwitchCpuMode(){
    if [[ ! -z "${1}" ]];then
        local CpuModePath=/sys/devices/system/cpu/eas/enable
        local GetMode="$(MtkCpuThings "${1}" number)"
        local GetModeDetail="$(MtkCpuThings "${1}" string)"
        if [[ -f ${CpuModePath} ]] && [[ "$GetMode" != *"Not Supported"* ]];then
            local GetBefore="$(MtkCpuThings "$CpuModePath" string)"
            if [[ "$GetBefore" != "$GetModeDetail" ]];then
                WriteOnly "$GetMode" "${CpuModePath}"
                sleep 1s
                if [[ "$(MtkCpuThings "$CpuModePath" string)" != "$GetBefore" ]];then
                    SendLogs "Switch kernel mode to $GetModeDetail done"
                else
                    SendLogs "Switch kernel mode failed($CpuChangeFail), ur current kernel not supported it"
                    if [[ "${CpuChangeFail}" -lt "5" ]];then
                        CpuChangeFail=$(($CpuChangeFail+1))
                    else
                        [[ "$(cat $PMConfig/mtk_cpu_mode_off.conf)" != "Not Supported" ]] && WriteOnly "Not Supported" $PMConfig/mtk_cpu_mode_off.conf
                        [[ "$(cat $PMConfig/mtk_cpu_mode_on.conf)" != "Not Supported" ]] && WriteOnly "Not Supported" $PMConfig/mtk_cpu_mode_on.conf
                    fi
                fi
            fi
        fi
    else
        [[ "$(cat $PMConfig/mtk_cpu_mode_off.conf)" != "Not Supported" ]] && WriteOnly "Not Supported" $PMConfig/mtk_cpu_mode_off.conf
        [[ "$(cat $PMConfig/mtk_cpu_mode_on.conf)" != "Not Supported" ]] && WriteOnly "Not Supported" $PMConfig/mtk_cpu_mode_on.conf
    fi
    GetErrorMsg "SwitchCpuMode"
} 2>>$RLOGsE

MtkCpuThings(){
    if [[ ! -z "$1" ]] && [[ ! -z "$2" ]];then
        local GetMode="$(cat $1)"
        if [[ "${GetMode}" == "<auto-generated>" ]] || [[ -f "${1}" ]];then
            CheckFileConfig && GetMode=$(cat ${1})
        fi
        local output=""
        if [[ "$GetMode" != "Not Supported" ]];then
            if [[ "$(echo $GetMode | tr '[:lower:]' '[:upper:]' )" == *"HMP"* ]] || [[ "$GetMode" == "0" ]];then
                [[ "$2" == "string" ]] && output="HMP"
                [[ "$2" == "number" ]] && output="0"
            elif [[ "$(echo $GetMode | tr '[:lower:]' '[:upper:]' )" == *"EAS"* ]] || [[ "$GetMode" == "1" ]];then
                [[ "$2" == "string" ]] && output="EAS"
                [[ "$2" == "number" ]] && output="1"
            elif [[ "$(echo $GetMode | tr '[:lower:]' '[:upper:]' )" == *"HYBRID"* ]] || [[ "$GetMode" == "2" ]];then
                [[ "$2" == "string" ]] && output="HYBRID"
                [[ "$2" == "number" ]] && output="2"
            else
                output="Not Supported"
            fi
        else
            output="Not Supported"
        fi
        [[ -z "$output" ]] && output="Not Supported"
        echo "$output"
    fi
}

DoDropCache(){
    local DropVal="$(cat $PMConfig/drop_caches.conf)"
    local DropValTime="$(cat $PMConfig/drop_caches_time.conf)"
    local DoDropCacheNow=""
    local clearType=""
    [[ "$(GetDisplayStatus)" == "off" ]] && [[ "$DropValTime" -le "20" ]] && DropValTime="$(($DropValTime*2))"
    if [[ -f /proc/sys/vm/drop_caches ]] && [[ "$DropVal" != "0" ]];then
        if [[ -z "$LastDropCache" ]];then
            DoDropCacheNow="y"
        elif [[ "$LastDropCache" -lt "$(AddTime "0")" ]];then
            DoDropCacheNow="y"
        else
            DoDropCacheNow="n"
        fi

        [[ "$(echo $LastDropCache | head -c2 )" == "00" ]] && [[ "$(date +"%H")" == "23" ]] && DoDropCacheNow="n"

        if [[ "$DropVal" -gt "3" ]];then
            DropVal="3"
            WriteOnly $DropVal $PMConfig/drop_caches.conf
        elif [[ "$DropVal" -lt "0" ]];then
            DropVal="0"
            WriteOnly $DropVal $PMConfig/drop_caches.conf
            DoDropCacheNow="n"
        fi

        if [[ "$DoDropCacheNow" == "y" ]];then
            # 1 = clear pageCache only.
            # 2 = clear dentries and inodes.
            # 3 = clear pagecache, dentries, and inodes.
            [[ "$DropVal" == "1" ]] && clearType="pageCache"
            [[ "$DropVal" == "2" ]] && clearType="dentries and inodes"
            [[ "$DropVal" == "3" ]] && clearType="pagecache, dentries, and inodes"
            WriteOnly $DropVal /proc/sys/vm/drop_caches
            LastDropCache="$(AddTime "$DropValTime")"
            SendLogs "clear ram $clearType success, will be triggered again at $(AddTime "$DropValTime" proper)"
        fi
    fi
    GetErrorMsg "DoDropCache"
} 2>>$RLOGsE

SetForceDoze(){
    [[ ! -f $PMConfig/force_doze.conf ]] && CheckFileConfig
    local ForceDozeConfig="$(cat $PMConfig/force_doze.conf)"
    if [[ "$ForceDozeConfig" == "1" ]];then
        local DisplayStatus="$(GetDisplayStatus)"
        if [[ ! -z "$DisplayStatus" ]] && [[ "$DisplayStatus" != "unknow" ]];then
            if [[ "$ScreenState" == "on" ]] && [[ "$DisplayStatus" == "off" ]];then
                if [[ "$SwitchForceDoze" == "2" ]];then
                    dumpsys deviceidle force-idle
                    ScreenState="off"
                    SendLogs "Screen off,forcing to doze state"
                    SwitchForceDoze="0"
                    CpuFreqLock "Sleep"
                else
                    SwitchForceDoze=$(($SwitchForceDoze+1))
                fi
                if [[ "$RunModules" == "2" ]];then
                    [[ -z "$MaxCheckGpuUsage" ]] && local MaxCheckGpuUsage="$(cat $PMConfig/max_check_gpu_usage.conf)"
                    GoTurbo="0"
                    GoNormal="$MaxCheckGpuUsage"
                fi
            elif [[ "$ScreenState" == "off" ]] && [[ "$DisplayStatus" == "on" ]];then
                dumpsys deviceidle unforce
                ScreenState="on"
                SendLogs "Screen on,unforcing doze state"
                CpuFreqLock "Unsleep"
            fi
        fi
    else
        if [[ "$ForceDozeConfig" != "0" ]];then
            WriteOnly "0" $PMConfig/force_doze.conf
        fi
    fi
    GetErrorMsg "SetForceDoze"
} 2>>$RLOGsE

CheckFileConfig(){
    [[ ! -f $PMConfig/min_gpu_usage.conf ]] && WriteOnly "5" $PMConfig/min_gpu_usage.conf

    [[ ! -f $PMConfig/max_gpu_usage.conf ]] && WriteOnly "70" $PMConfig/max_gpu_usage.conf

    [[ ! -f $PMConfig/max_check_gpu_usage.conf ]] && WriteOnly "3" $PMConfig/max_check_gpu_usage.conf

    [[ ! -f $PMConfig/wait_when_on.conf ]] && WriteOnly "10s" $PMConfig/wait_when_on.conf

    [[ ! -f $PMConfig/wait_when_off.conf ]] && WriteOnly "5s" $PMConfig/wait_when_off.conf

    [[ ! -f $PMConfig/manual_game_list.conf ]] && WriteOnly "com.mobile.legends com.pubg.krmobile com.pwrd.pwm tw.com.szn.lz com.zloong.eu.dr.gp com.archosaur.sea.dr.gp com.kr.krlz.google com.tencent com.garena com.miHoYo com.gamedreamer com.netease" $PMConfig/manual_game_list.conf

    [[ ! -f $PMConfig/modules_mode.conf ]] && WriteOnly "Auto" $PMConfig/modules_mode.conf

    if [[ -f /sys/class/thermal/thermal_message/sconfig ]];then

        [[ ! -f $PMConfig/sconfig.thermal.conf ]] && WriteOnly "16" $PMConfig/sconfig.thermal.conf

        [[ ! -f $PMConfig/sconfig.thermal.lock.conf ]] && WriteOnly "0" $PMConfig/sconfig.thermal.lock.conf
    else
        if [[ -f $PMConfig/sconfig.thermal.conf ]] ;then
            [[ "$(cat $PMConfig/sconfig.thermal.conf)" != "Not Supported" ]] && WriteOnly "Not Supported" $PMConfig/sconfig.thermal.conf
        else
            WriteOnly "Not Supported" $PMConfig/sconfig.thermal.conf
        fi
        
        if [[ -f $PMConfig/sconfig.thermal.lock.conf ]];then
            [[ "$(cat $PMConfig/sconfig.thermal.lock.conf)" != "Not Supported" ]] && WriteOnly "Not Supported" $PMConfig/sconfig.thermal.lock.conf
        else
            WriteOnly "Not Supported" $PMConfig/sconfig.thermal.lock.conf
        fi

    fi

    if [[ ! -f $PMConfig/scheduler.conf ]] || [[ "$(cat $PMConfig/scheduler.conf)" == "default" ]];then
        local ChangeSchedTo="cfq"
        local BlockSD
        for BlockSD in $(ls /sys/block | grep sd)
        do
            if [[ "${#BlockSD}" == "3" ]];then
                local SchedList="$(cat /sys/block/$BlockSD/queue/scheduler)"
                if [[ "$SchedList" == *"noop"* ]];then
                    ChangeSchedTo="noop" && break
                fi
            fi
        done
        if [[ "$ChangeSchedTo" == "cfq" ]];then
            for BlockSD in $(ls /sys/block | grep mmcblk)
            do
                if [[ "${#BlockSD}" == "7" ]];then
                    local SchedList="$(cat /sys/block/$BlockSD/queue/scheduler)"
                    if [[ "$SchedList" == *"noop"* ]];then
                        ChangeSchedTo="noop" && break
                    fi
                fi
            done
        fi
        WriteOnly $ChangeSchedTo $PMConfig/scheduler.conf
    fi

    [[ ! -f $PMConfig/scheduler.lock.conf ]] && WriteOnly "0" $PMConfig/scheduler.lock.conf

    [[ ! -f $PMConfig/show_error.conf ]] && WriteOnly "1" $PMConfig/show_error.conf

    if [[ -f /sys/devices/system/cpu/eas/enable ]];then
        if [[ ! -f $PMConfig/mtk_cpu_mode_on.conf ]];then
            WriteOnly "0" $PMConfig/mtk_cpu_mode_on.conf
        else
            [[ "$(cat $PMConfig/mtk_cpu_mode_on.conf)" == "<auto-generated>" ]] && WriteOnly "0" $PMConfig/mtk_cpu_mode_on.conf
        fi
        if [[ ! -f $PMConfig/mtk_cpu_mode_off.conf ]];then
            WriteOnly "1" $PMConfig/mtk_cpu_mode_off.conf
        else
            [[ "$(cat $PMConfig/mtk_cpu_mode_off.conf)" == "<auto-generated>" ]] && WriteOnly "1" $PMConfig/mtk_cpu_mode_off.conf
        fi
    else
        if [[ ! -f $PMConfig/mtk_cpu_mode_off.conf ]];then
            WriteOnly "Not Supported" $PMConfig/mtk_cpu_mode_off.conf
        else
            [[ "$(cat $PMConfig/mtk_cpu_mode_off.conf)" != "Not Supported" ]] && WriteOnly "Not Supported" $PMConfig/mtk_cpu_mode_off.conf
        fi
        if [[ ! -f $PMConfig/mtk_cpu_mode_on.conf ]];then
            WriteOnly "Not Supported" $PMConfig/mtk_cpu_mode_on.conf
        else
            [[ "$(cat $PMConfig/mtk_cpu_mode_on.conf)" != "Not Supported" ]] && WriteOnly "Not Supported" $PMConfig/mtk_cpu_mode_on.conf
        fi
    fi

    if [[ -f /proc/sys/vm/drop_caches ]];then
        [[ ! -f $PMConfig/drop_caches.conf ]] && WriteOnly "0" $PMConfig/drop_caches.conf
        [[ ! -f $PMConfig/drop_caches_time.conf ]] && WriteOnly "60" $PMConfig/drop_caches_time.conf
    else
        if [[ -f $PMConfig/drop_caches.conf ]];then
            [[ "$(cat $PMConfig/drop_caches.conf)" != "Not Supported" ]] && WriteOnly "Not Supported" $PMConfig/drop_caches.conf
        else
            WriteOnly "Not Supported" $PMConfig/drop_caches.conf
        fi
        if [[ -f $PMConfig/drop_caches_time.conf ]];then
            [[ "$(cat $PMConfig/drop_caches_time.conf)" != "Not Supported" ]] && WriteOnly "Not Supported" $PMConfig/drop_caches_time.conf
        else
            WriteOnly "Not Supported" $PMConfig/drop_caches_time.conf
        fi
    fi

    [[ ! -f $PMConfig/force_doze.conf ]] && WriteOnly "0" $PMConfig/force_doze.conf

    [[ ! -f $PMConfig/use_cpu_tweak.conf ]] && WriteOnly "1:3" $PMConfig/use_cpu_tweak.conf

    [[ -f $PMConfig/use_cpu_tweak.conf ]] && [[ "$(cat $PMConfig/use_cpu_tweak.conf)" == "1" ]] && WriteOnly "1:3" $PMConfig/use_cpu_tweak.conf

    [[ ! -f $PMConfig/silent_overwrite.conf ]] && WriteOnly "0" $PMConfig/silent_overwrite.conf

    [[ ! -f $PMConfig/write_info.conf ]] && WriteOnly "1" $PMConfig/write_info.conf

    [[ ! -f $PMConfig/status.conf ]] && WriteOnly "1" $PMConfig/status.conf

    if [[ ! -f $PMConfig/gov_off.conf ]];then
        UpdateGov backup "$PMConfig/gov_off.conf"
    else
        [[ "$(cat $PMConfig/gov_off.conf)" == "<auto-generated>" ]] && UpdateGov backup "$PMConfig/gov_off.conf"
    fi

    if [[ ! -f $PMConfig/gov_on.conf ]];then
        UpdateGov backup "$PMConfig/gov_on.conf"
    else
        [[ "$(cat $PMConfig/gov_on.conf)" == "<auto-generated>" ]] && UpdateGov backup "$PMConfig/gov_on.conf"
    fi

    if [[ -d /sys/module/cpu_input_boost/parameters ]];then
        [[ ! -f $PMConfig/cib_on.conf ]] && WriteOnly "enabled:1" $PMConfig/cib_on.conf
        [[ ! -f $PMConfig/cib_off.conf ]] && WriteOnly "enabled:0" $PMConfig/cib_off.conf
    else
        if [[ -f $PMConfig/cib_on.conf ]];then
            [[ "$(cat $PMConfig/cib_on.conf)" != "Not Supported" ]] && WriteOnly "Not Supported" $PMConfig/cib_on.conf
        else
            WriteOnly "Not Supported" $PMConfig/cib_on.conf
        fi
        if [[ -f $PMConfig/cib_off.conf ]];then
            [[ "$(cat $PMConfig/cib_off.conf)" != "Not Supported" ]] && WriteOnly "Not Supported" $PMConfig/cib_off.conf
        else
            WriteOnly "Not Supported" $PMConfig/cib_off.conf
        fi
    fi

    [[ ! -f $PMConfig/zram.conf ]] && WriteOnly "0" $PMConfig/zram.conf

    [[ ! -f $PMConfig/zram_ext.conf ]] && WriteOnly "-1" $PMConfig/zram_ext.conf

    GetErrorMsg "CheckFileConfig"
} 2>>$RLOGsE

UpdateGov(){
    local Doing="$1"
    local getConfig="$2"
    local valConfig="$(cat $2)"
    local GetClustersNumber
    for GetClustersNumber in $(ls /sys/devices/system/cpu/cpufreq | grep policy)
    do
        
        [[ "$Doing" == "backup" ]] && WriteTo "$(cat /sys/devices/system/cpu/cpufreq/$GetClustersNumber/scaling_governor)" $getConfig
        [[ "$Doing" == "write" ]] && [[ ! -z "$(cat /sys/devices/system/cpu/cpufreq/$GetClustersNumber/scaling_available_governors | grep $valConfig)" ]] && WriteTo "$valConfig" /sys/devices/system/cpu/cpufreq/$GetClustersNumber/scaling_governor
    done
}

RealGetDisplayStatus(){
    local stopNow="n"
    local GetByPowerService="$( dumpsys power | grep "mHoldingDisplaySuspendBlocker" | sed 's/mHoldingDisplaySuspendBlocker=*//g' )"
    if [[ "$GetByPowerService" == *"ON"* ]];then
        [[ "$stopNow" == "n" ]] && echo "on"
        stopNow="y"
    elif [[ "$GetByPowerService" == *"OFF"* ]];then
        [[ "$stopNow" == "n" ]] && echo "off"
        stopNow="y"
    fi
    if [[ "$stopNow" == "n" ]];then
        local GetByDisplayService="$( dumpsys display | grep "mScreenState" | sed 's/mScreenState=*//g' )"
        if [[ "$GetByDisplayService" == *"ON"* ]];then
            [[ "$stopNow" == "n" ]] && echo "on"
            stopNow="y"
        elif [[ "$GetByDisplayService" == *"OFF"* ]];then
            [[ "$stopNow" == "n" ]] && echo "off"
            stopNow="y"
        fi
    fi
    if [[ "$stopNow" == "n" ]];then
        local GetByNFCService="$( dumpsys nfc | grep 'mScreenState=' | sed 's/mScreenState=*//g' )"
        if [[ "$GetByNFCService" == *"ON_LOCKED"* ]] && [[ "$GetByNFCService" == *"ON_UNLOCKED"* ]];then
            [[ "$stopNow" == "n" ]] && echo "on"
            stopNow="y"
        elif [[ "$GetByNFCService" == *"OFF_LOCKED"* ]] && [[ "$GetByNFCService" == *"OFF_UNLOCKED"* ]];then
            [[ "$stopNow" == "n" ]] && echo "off"
            stopNow="y"
        fi
    fi
    [[ "$stopNow" == "n" ]] && echo "unknow"
    # GetErrorMsg "RealGetDisplayStatus"
} 2>>$RLOGsE

GetDisplayStatus(){
    [[ "$StopGetDisplay" == "n" ]] && CurrentDisplayStatus="$(RealGetDisplayStatus)"
    StopGetDisplay="y"
    if [[ -z "$CurrentDisplayStatus" ]];then
        echo "on"
    else
        echo "$CurrentDisplayStatus"
    fi
}

CpuBalance(){
    local UINT_MAX="4294967295"
    local SCHED_PERIOD="$((4 * 1000 * 1000))"
    local SCHED_TASKS="8"
    local IFS
    local governor
    local queue
    local VTwo="${1}"
    WriteSysKernel  perf_cpu_time_max_percent:5 sched_autogroup_enabled:1 sched_child_runs_first:1 sched_tunable_scaling:0 "sched_latency_ns:$SCHED_PERIOD" \
                    "sched_min_granularity_ns:$((SCHED_PERIOD / SCHED_TASKS))" "sched_wakeup_granularity_ns:$((SCHED_PERIOD / 2))" sched_migration_cost_ns:5000000 \
                    sched_min_task_util_for_colocation:0 sched_nr_migrate:32 sched_schedstats:0 printk_devkmsg:off
    WriteTo 0 /dev/stune/top-app/schedtune.prefer_idle
    WriteTo 1 /dev/stune/top-app/schedtune.boost

    find /sys/devices/system/cpu/ -name schedutil -type d | while IFS= read -r governor
    do
        if [[ ! -z "$VTwo" ]];then
            WriteTo "$((4 * SCHED_PERIOD / 1000))" "$governor/up_rate_limit_us"
            WriteTo "$((4 * SCHED_PERIOD / 1000))" "$governor/rate_limit_us"
        else
            WriteTo "$((SCHED_PERIOD / 1000))" "$governor/up_rate_limit_us"
            WriteTo "$((SCHED_PERIOD / 1000))" "$governor/rate_limit_us"
        fi
        WriteTo "$((4 * SCHED_PERIOD / 1000))" "$governor/down_rate_limit_us"
        WriteTo 90 "$governor/hispeed_load"
        WriteTo "$UINT_MAX" "$governor/hispeed_freq"
    done

    find /sys/devices/system/cpu/ -name blu_schedutil -type d | while IFS= read -r governor
    do
        if [[ ! -z "$VTwo" ]];then
            WriteTo "$((4 * SCHED_PERIOD / 1000))" "$governor/up_rate_limit_us"
            WriteTo "$((4 * SCHED_PERIOD / 1000))" "$governor/rate_limit_us"
        else
            WriteTo "$((SCHED_PERIOD / 1000))" "$governor/up_rate_limit_us"
            WriteTo "$((SCHED_PERIOD / 1000))" "$governor/rate_limit_us"
        fi
        WriteTo "$((4 * SCHED_PERIOD / 1000))" "$governor/down_rate_limit_us"
        WriteTo 90 "$governor/hispeed_load"
        WriteTo "$UINT_MAX" "$governor/hispeed_freq"
    done

    find /sys/devices/system/cpu/ -name interactive -type d | while IFS= read -r governor
    do
        WriteTo "$((SCHED_PERIOD / 1000))" "$governor/timer_rate"
        WriteTo "$((SCHED_PERIOD / 1000))" "$governor/min_sample_time"
        WriteTo 90 "$governor/go_hispeed_load"
        WriteTo "$UINT_MAX" "$governor/hispeed_freq"
    done

    for queue in /sys/block/*/queue
    do
        WriteTo 0 "$queue/add_random"
        WriteTo 0 "$queue/iostats"
        WriteTo 128 "$queue/read_ahead_kb"
        WriteTo 64 "$queue/nr_requests"
    done
}

VmBalance(){
    WriteSysVm  dirty_background_ratio:10 dirty_ratio:30 dirty_expire_centisecs:3000 dirty_writeback_centisecs:3000 page-cluster:0 stat_interval:10 \
                swappiness:100 vfs_cache_pressure:100
}

CpuPerformance(){
    local UINT_MAX="4294967295"
    local SCHED_PERIOD="$((10 * 1000 * 1000))"
    local SCHED_TASKS="6"
    local IFS
    local governor
    local queue
    local VTwo="${1}"
    WriteSysKernel  perf_cpu_time_max_percent:20 sched_autogroup_enabled:0 sched_child_runs_first:0 sched_tunable_scaling:0 "sched_latency_ns:$SCHED_PERIOD" \
                    "sched_min_granularity_ns:$((SCHED_PERIOD / SCHED_TASKS))" "sched_wakeup_granularity_ns:$((SCHED_PERIOD / 2))" sched_migration_cost_ns:5000000 \
                    sched_min_task_util_for_colocation:0 sched_nr_migrate:128 sched_schedstats:0 printk_devkmsg:off

    WriteTo 0 /dev/stune/top-app/schedtune.prefer_idle
    WriteTo 1 /dev/stune/top-app/schedtune.boost

    find /sys/devices/system/cpu/ -name schedutil -type d | while IFS= read -r governor
    do
        if [[ ! -z "$VTwo" ]];then
            WriteTo "$((4 * SCHED_PERIOD / 1000))" "$governor/up_rate_limit_us"
            WriteTo "$((4 * SCHED_PERIOD / 1000))" "$governor/rate_limit_us"
        else
            WriteTo "$((SCHED_PERIOD / 1000))" "$governor/up_rate_limit_us"
            WriteTo "$((SCHED_PERIOD / 1000))" "$governor/rate_limit_us"
        fi
        WriteTo "$((4 * SCHED_PERIOD / 1000))" "$governor/down_rate_limit_us"
        WriteTo 85 "$governor/hispeed_load"
        WriteTo "$UINT_MAX" "$governor/hispeed_freq"
    done

    find /sys/devices/system/cpu/ -name blu_schedutil -type d | while IFS= read -r governor
    do
        if [[ ! -z "$VTwo" ]];then
            WriteTo "$((4 * SCHED_PERIOD / 1000))" "$governor/up_rate_limit_us"
            WriteTo "$((4 * SCHED_PERIOD / 1000))" "$governor/rate_limit_us"
        else
            WriteTo "$((SCHED_PERIOD / 1000))" "$governor/up_rate_limit_us"
            WriteTo "$((SCHED_PERIOD / 1000))" "$governor/rate_limit_us"
        fi
        WriteTo "$((4 * SCHED_PERIOD / 1000))" "$governor/down_rate_limit_us"
        WriteTo 85 "$governor/hispeed_load"
        WriteTo "$UINT_MAX" "$governor/hispeed_freq"
    done

    find /sys/devices/system/cpu/ -name interactive -type d | while IFS= read -r governor
    do
        WriteTo "$((SCHED_PERIOD / 1000))" "$governor/timer_rate"
        WriteTo "$((SCHED_PERIOD / 1000))" "$governor/min_sample_time"
        WriteTo 85 "$governor/go_hispeed_load"
        WriteTo "$UINT_MAX" "$governor/hispeed_freq"
    done

    for queue in /sys/block/*/queue
    do
        WriteTo 0 "$queue/add_random"
        WriteTo 0 "$queue/iostats"
        WriteTo 256 "$queue/read_ahead_kb"
        WriteTo 512 "$queue/nr_requests"
    done

}

VmPerformance(){
    WriteSysVm  dirty_background_ratio:15 dirty_ratio:30 dirty_expire_centisecs:3000 dirty_writeback_centisecs:3000 page-cluster:0 stat_interval:10 \
                swappiness:100 vfs_cache_pressure:80
}

CpuPerformanceB(){
    local UINT_MAX="4294967295"
    local SCHED_PERIOD="$((1 * 1000 * 1000))"
    local SCHED_TASKS="10"
    local IFS
    local governor
    local queue
    WriteSysKernel  perf_cpu_time_max_percent:3 sched_autogroup_enabled:1 sched_child_runs_first:1 sched_tunable_scaling:0 "sched_latency_ns:$SCHED_PERIOD" \
                    "sched_min_granularity_ns:$((SCHED_PERIOD / SCHED_TASKS))" "sched_wakeup_granularity_ns:$((SCHED_PERIOD / 2))" sched_migration_cost_ns:5000000 \
                    sched_min_task_util_for_colocation:0 sched_nr_migrate:4 sched_schedstats:0 printk_devkmsg:off

    WriteTo 1 /dev/stune/top-app/schedtune.prefer_idle
    WriteTo 1 /dev/stune/top-app/schedtune.boost

    find /sys/devices/system/cpu/ -name schedutil -type d | while IFS= read -r governor
    do
        WriteTo "0" "$governor/up_rate_limit_us"
        WriteTo "0" "$governor/down_rate_limit_us"
        WriteTo "0" "$governor/rate_limit_us"
        WriteTo 85 "$governor/hispeed_load"
        WriteTo "$UINT_MAX" "$governor/hispeed_freq"
    done

    find /sys/devices/system/cpu/ -name blu_schedutil -type d | while IFS= read -r governor
    do
        WriteTo "0" "$governor/up_rate_limit_us"
        WriteTo "0" "$governor/down_rate_limit_us"
        WriteTo "0" "$governor/rate_limit_us"
        WriteTo 85 "$governor/hispeed_load"
        WriteTo "$UINT_MAX" "$governor/hispeed_freq"
    done

    find /sys/devices/system/cpu/ -name interactive -type d | while IFS= read -r governor
    do
        WriteTo "0" "$governor/timer_rate"
        WriteTo "0" "$governor/min_sample_time"
        WriteTo 85 "$governor/go_hispeed_load"
        WriteTo "$UINT_MAX" "$governor/hispeed_freq"
    done

    for queue in /sys/block/*/queue
    do
        WriteTo 0 "$queue/add_random"
        WriteTo 0 "$queue/iostats"
        WriteTo 32 "$queue/read_ahead_kb"
        WriteTo 32 "$queue/nr_requests"
    done

}

VmPerformanceB(){
    WriteSysVm  dirty_background_ratio:15 dirty_ratio:30 dirty_expire_centisecs:3000 dirty_writeback_centisecs:3000 page-cluster:0 stat_interval:10 \
                swappiness:100 vfs_cache_pressure:80
}

DoCpuTweak()
{
    local mode="${1}"
    if [[ "$mode" == "1" ]];then
        # https://github.com/tytydraco/KTweak/tree/balance
        CpuBalance
        VmBalance
    elif [[ "$mode" == "2" ]];then
        # https://github.com/tytydraco/KTweak/tree/balance + tweaked
        CpuBalance "y"
        VmBalance
    elif [[ "$mode" == "3" ]];then
        # https://github.com/tytydraco/KTweak/tree/throughput
        CpuPerformance
        VmPerformance
    elif [[ "$mode" == "4" ]];then
        # https://github.com/tytydraco/KTweak/tree/throughput + tweaked
        CpuPerformance "y"
        VmPerformance
    elif [[ "$mode" == "5" ]];then
        # https://github.com/tytydraco/KTweak/tree/latency
        CpuPerformanceB
        VmPerformanceB
    fi
}

SetFreqCpu(){
    local Lt="-1"
    local Bg="-1"
    local Pm="-1"
    local mode="$1"
    local ForLt="$2"
    local ForBg="$3"
    local ForPm="$4"
    local TotalClusters="0"
    for GetClustersNumber in $(ls /sys/devices/system/cpu/cpufreq | grep policy)
    do
        TotalClusters=$(($TotalClusters+1))
        if [[ "$Lt" == "-1" ]];then
            Lt="$(echo $GetClustersNumber | awk -F 'policy' '{print $2}')"
            if [[ "$2" == "default" ]] || [[ -z "$ForLt" ]] || [[ "$ForLt" == "0" ]];then
                local GetInfoFreq
                for GetInfoFreq in $(cat /sys/devices/system/cpu/cpufreq/$GetClustersNumber/scaling_available_frequencies)
                do
                    if [[ -z "$ForLt" ]] || [[ "$ForLt" == "0" ]] || [[ -z "$(echo $ForLt | grep -q "^[0-9]*$" && echo "OK")" ]];then
                        ForLt="$GetInfoFreq"
                    elif [[ "$mode" == "max" ]] && [[ "$ForLt" -le "$GetInfoFreq" ]];then
                        ForLt="$GetInfoFreq"
                    elif [[ "$mode" == "min" ]] && [[ "$ForLt" -ge "$GetInfoFreq" ]];then
                        ForLt="$GetInfoFreq"
                    fi
                done
            fi
            WriteOnly "$ForLt" /sys/devices/system/cpu/cpufreq/$GetClustersNumber/scaling_${mode}_freq
            WriteTo "$ForLt" /sys/devices/system/cpu/cpufreq/$GetClustersNumber/cpuinfo_${mode}_freq
        elif [[ "$Bg" == "-1" ]];then
            Bg="$(echo $GetClustersNumber | awk -F 'policy' '{print $2}')"
            if [[ "$2" == "default" ]] || [[ -z "$ForBg" ]] || [[ "$ForBg" == "0" ]];then
                local GetInfoFreq
                for GetInfoFreq in $(cat /sys/devices/system/cpu/cpufreq/$GetClustersNumber/scaling_available_frequencies)
                do
                    if [[ -z "$ForBg" ]] || [[ "$ForBg" == "0" ]] || [[ -z "$(echo $ForBg | grep -q "^[0-9]*$" && echo "OK")" ]];then
                        ForBg="$GetInfoFreq"
                    elif [[ "$mode" == "max" ]] && [[ "$ForBg" -le "$GetInfoFreq" ]];then
                        ForBg="$GetInfoFreq"
                    elif [[ "$mode" == "min" ]] && [[ "$ForBg" -ge "$GetInfoFreq" ]];then
                        ForBg="$GetInfoFreq"
                    fi
                done
            fi
            WriteOnly "$ForBg" /sys/devices/system/cpu/cpufreq/$GetClustersNumber/scaling_${mode}_freq
            WriteTo "$ForBg" /sys/devices/system/cpu/cpufreq/$GetClustersNumber/cpuinfo_${mode}_freq
        elif [[ "$Pm" == "-1" ]];then
            Pm="$(echo $GetClustersNumber | awk -F 'policy' '{print $2}')"
            if [[ "$2" == "default" ]] || [[ -z "$ForPm" ]] || [[ "$ForPm" == "0" ]];then
                local GetInfoFreq
                for GetInfoFreq in $(cat /sys/devices/system/cpu/cpufreq/$GetClustersNumber/scaling_available_frequencies)
                do
                    if [[ -z "$ForPm" ]] || [[ "$ForPm" == "0" ]] || [[ -z "$(echo $ForPm | grep -q "^[0-9]*$" && echo "OK")" ]];then
                        ForPm="$GetInfoFreq"
                    elif [[ "$mode" == "max" ]] && [[ "$ForPm" -le "$GetInfoFreq" ]];then
                        ForPm="$GetInfoFreq"
                    elif [[ "$mode" == "min" ]] && [[ "$ForPm" -ge "$GetInfoFreq" ]];then
                        ForPm="$GetInfoFreq"
                    fi
                done
            fi
            WriteOnly "$ForPm" /sys/devices/system/cpu/cpufreq/$GetClustersNumber/scaling_${mode}_freq
            WriteTo "$ForPm" /sys/devices/system/cpu/cpufreq/$GetClustersNumber/cpuinfo_${mode}_freq
        fi
    done
    local prepCmd=""
    local ListCPUs
    local SpaceCharacter=" "
    for ListCPUs in 0 1 2 3 4 5 6 7;do
        [[ "$ListCPUs" == "7" ]] && SpaceCharacter=""
        if [[ "$ListCPUs" -ge "$Pm" ]];then
            prepCmd="${prepCmd}${ListCPUs}:${ForPm}${SpaceCharacter}"
        elif [[ "$ListCPUs" -ge "$Bg" ]];then
            prepCmd="${prepCmd}${ListCPUs}:${ForBg}${SpaceCharacter}"
        elif [[ "$ListCPUs" -ge "$Lt" ]];then
            prepCmd="${prepCmd}${ListCPUs}:${ForLt}${SpaceCharacter}"
        fi
    done
    if [[ -e /sys/module/msm_performance/parameters/cpu_${mode}_freq ]];then
        WriteOnly "$prepCmd" /sys/module/msm_performance/parameters/cpu_${mode}_freq
    fi
    if [[ -e "/proc/ppm/policy/hard_userlimit_${mode}_cpu_freq" ]];then
        Setppm enabled 1
        Setppm policy_status "7 1"
        [[ "$TotalClusters" -ge "1" ]] && WriteOnly "0 $ForLt" "/proc/ppm/policy/hard_userlimit_${mode}_cpu_freq" && SendLogs "Set $mode Little Cluster To $1"
        [[ "$TotalClusters" -ge "2" ]] && WriteOnly "1 $ForBg" "/proc/ppm/policy/hard_userlimit_${mode}_cpu_freq" && SendLogs "Set $mode Big Cluster To $2"
        [[ "$TotalClusters" -ge "3" ]] && WriteOnly "2 $ForPm" "/proc/ppm/policy/hard_userlimit_${mode}_cpu_freq" && SendLogs "Set $mode Prime Cluster To $3"
    fi
    GetErrorMsg "SetFreqCpu"
} 2>>$RLOGsE

CpuSetOn(){
    local i
    for i in 0 1 2 3 4 5 6 7
    do
        [[ ! -z "$(cat $1 | grep $i)" ]] && [[ -f /sys/devices/system/cpu/cpu$i/online ]] && WriteTo 1 /sys/devices/system/cpu/cpu$i/online
        [[ -z "$(cat $1 | grep $i)" ]] && [[ -f /sys/devices/system/cpu/cpu$i/online ]] && WriteTo 0 /sys/devices/system/cpu/cpu$i/online
    done
    GetErrorMsg "SetCpuAllOnline"
} 2>>$RLOGsE

CpuFreqLock(){
    if [[ "$1" == "Lock" ]];then
        if [[ "$CPUFREQLOCKSTATUS" == "n" ]];then
            if [[ -e $PMConfig/cpu_on_lock.conf ]];then
                local number=1
                local ForMin=""
                local ForMax=""
                for GetVal in $(cat $PMConfig/cpu_on_lock.conf)
                do
                    if [[ "$number" == "1" ]] || [[ "$number" == "3" ]] || [[ "$number" == "5" ]];then
                        ForMin="$ForMin $GetVal"
                    else
                        ForMax="$ForMax $GetVal"
                    fi
                    number=$(($number+1))
                done
                SetFreqCpu min $ForMin
                SetFreqCpu max $ForMax
                CPUFREQLOCKSTATUS="y"
                [[ -e $PMConfig/cpu_on_lock_set.conf ]] && CpuSetOn $PMConfig/cpu_on_lock_set.conf
            fi
        fi
    elif [[ "$1" == "Unlock" ]];then
        if [[ "$CPUFREQLOCKSTATUS" == "y" ]];then
            if [[ -e $PMConfig/cpu_on_boot_lock.conf ]];then
                local number=1
                local ForMin=""
                local ForMax=""
                for GetVal in $(cat $PMConfig/cpu_on_boot_lock.conf)
                do
                    if [[ "$number" == "1" ]] || [[ "$number" == "3" ]] || [[ "$number" == "5" ]];then
                        ForMin="$ForMin $GetVal"
                    else
                        ForMax="$ForMax $GetVal"
                    fi
                    number=$(($number+1))
                done
                SetFreqCpu min $ForMin
                SetFreqCpu max $ForMax
                [[ -e $PMConfig/cpu_on_boot_lock_set.conf ]] && CpuSetOn $PMConfig/cpu_on_boot_lock_set.conf
            else
                SetFreqCpu min "default"
                SetFreqCpu max "default"
            fi
            CPUFREQLOCKSTATUS="n"
        fi
    elif [[ "$1" == "Boot" ]];then
        if [[ -e $PMConfig/cpu_on_boot_lock.conf ]];then
            local number=1
            local ForMin=""
            local ForMax=""
            for GetVal in $(cat $PMConfig/cpu_on_boot_lock.conf)
            do
                if [[ "$number" == "1" ]] || [[ "$number" == "3" ]] || [[ "$number" == "5" ]];then
                    ForMin="$ForMin $GetVal"
                else
                    ForMax="$ForMax $GetVal"
                fi
                number=$(($number+1))
            done
            SetFreqCpu min $ForMin
            SetFreqCpu max $ForMax
            [[ -e $PMConfig/cpu_on_boot_lock_set.conf ]] && CpuSetOn $PMConfig/cpu_on_boot_lock_set.conf
        fi
    elif [[ "$1" == "Sleep" ]];then
        if [[ "$CPUFREQLOCKSTATUSSLEEP" == "n" ]];then
            if [[ -e $PMConfig/cpu_on_sleep_lock.conf ]];then
                local number=1
                local ForMin=""
                local ForMax=""
                for GetVal in $(cat $PMConfig/cpu_on_sleep_lock.conf)
                do
                    if [[ "$number" == "1" ]] || [[ "$number" == "3" ]] || [[ "$number" == "5" ]];then
                        ForMin="$ForMin $GetVal"
                    else
                        ForMax="$ForMax $GetVal"
                    fi
                    number=$(($number+1))
                done
                SetFreqCpu min $ForMin
                SetFreqCpu max $ForMax
                CPUFREQLOCKSTATUSSLEEP="y"
                [[ -e $PMConfig/cpu_on_sleep_lock_set.conf ]] && CpuSetOn $PMConfig/cpu_on_sleep_lock_set.conf
            fi
        fi
    elif [[ "$1" == "Unsleep" ]];then
        if [[ "$CPUFREQLOCKSTATUSSLEEP" == "y" ]];then
            if [[ -e $PMConfig/cpu_on_boot_lock.conf ]];then
                local number=1
                local ForMin=""
                local ForMax=""
                for GetVal in $(cat $PMConfig/cpu_on_boot_lock.conf)
                do
                    if [[ "$number" == "1" ]] || [[ "$number" == "3" ]] || [[ "$number" == "5" ]];then
                        ForMin="$ForMin $GetVal"
                    else
                        ForMax="$ForMax $GetVal"
                    fi
                    number=$(($number+1))
                done
                SetFreqCpu min $ForMin
                SetFreqCpu max $ForMax
                [[ -e $PMConfig/cpu_on_boot_lock_set.conf ]] && CpuSetOn $PMConfig/cpu_on_boot_lock_set.conf
            else
                SetFreqCpu min "default"
                SetFreqCpu max "default"
            fi
            CPUFREQLOCKSTATUSSLEEP="n"
        fi
    fi
    GetErrorMsg "CpuFreqLock"
} 2>>$RLOGsE

CpuInpuBoostUpdate(){
    local mode="$1"
    local ListFile
    local CurconVar
    if [[ "$mode" == "on" ]];then
        local conVar="$PMConfig/cib_on.conf"
    else
        local conVar="$PMConfig/cib_off.conf"
    fi
    if [[ -d /sys/module/cpu_input_boost/parameters ]] && [[ -e $conVar ]];then
        GetConfigVar "$(cat $conVar)"
        for ListFile in $(ls /sys/module/cpu_input_boost/parameters)
        do
            CurconVar="$(eval echo \$Var_$ListFile)"
            echo $ListFile" : "$CurconVar
            [[ ! -z "$CurconVar" ]] && WriteOnly "$CurconVar" /sys/module/cpu_input_boost/parameters/$ListFile && eval Var_$ListFile=""
            CurconVar=""
            eval Var_$ListFile=""
        done
    fi
    GetErrorMsg "CpuInpuBoostUpdate"
} 2>>$RLOGsE

## misc
FirstBootMsg(){
    echo "# initial logs" > $LOGs
    echo "# Copyright (C) 2022 ZyCromerZ" >> $LOGs
    echo "----< $( date +"%Y-%m-%d %H:%M:%S") >----" >> $LOGs
    echo "----< |First Boot| >----" >> $LOGsE
    echo "Module Version: $(grep_prop version)" >> $LOGs
    echo "Type Cpu: $TypeCpu" >> $LOGs
    echo "Type Gpu: $TypeGpu" >> $LOGs
    if [[ "$TypeGpu" == "Adreno" ]] || [[ "$TypeGpu" == "Mali" ]];then
        echo "Supported: Yes" >> $LOGs
    else
        echo "Supported: Still nope for now :(" >> $LOGs
    fi
    echo "# initial logs error" > $LOGsE
    echo "# Copyright (C) 2022 ZyCromerZ" >> $LOGsE
    echo "----< $( date +"%Y-%m-%d %H:%M:%S") >----" >> $LOGsE
    echo "----< |First Boot| >----" >> $LOGsE
    echo "Module Version: $(grep_prop version)" >> $LOGsE
}

AddTime(){
    local Hours="$(date +"%H")"
    local GetMinute="$(date +"%M")"
    local Seconds="$(date +"%S")"
    Hours=$(RemoveZero $Hours)
    GetMinute=$(RemoveZero $GetMinute)
    GetMinute=$(($GetMinute+${1}))
    if [[ "$GetMinute" -ge "60" ]];then
        local SisaNya=$(GetHour $GetMinute)
        Hours="$(($Hours+$SisaNya))"
        # Hours=$(OptimizeHour $Hours)
        if [[ $Hours -ge "24" ]];then
            Hours="0"
        fi
        GetMinute=$(OptimizeMinute $GetMinute)
    fi
    [[ "$GetMinute" -lt "10" ]] && GetMinute="0${GetMinute}"
    [[ "$Hours" -lt "10" ]] && Hours="0${Hours}"
    if [[ "$2" == "proper" ]];then
        echo "${Hours} : ${GetMinute} : ${Seconds}"
    else
        echo "1${Hours}${GetMinute}${Seconds}"
    fi
}

RemoveZero(){
    if [[ "${1}" == "00" ]] || [[ "${1}" == "01" ]] || [[ "${1}" == "02" ]] || [[ "${1}" == "03" ]] || [[ "${1}" == "04" ]] || [[ "${1}" == "05" ]] || [[ "${1}" == "06" ]] || [[ "${1}" == "07" ]] || [[ "${1}" == "08" ]] || [[ "${1}" == "09" ]];then
        echo ${1/"0"/""}
    else
        echo "${1}"
    fi
}

GetHour(){
    [[ -z "$AddmoreH" ]] && AddmoreH="0"
    local Total="$1"
    if [[ "$Total" -ge "60" ]];then
        Total="$(($Total-60))"
        AddmoreH="$(($AddmoreH+1))"
        if [[ "$Total" -ge "60" ]];then
            GetHour "$Total"
        else
            echo $AddmoreH
            AddmoreH="0"
        fi
    else
        echo "0"
    fi
}

OptimizeMinute(){
    [[ -z "$AddmoreM" ]] && AddmoreM=""
    local Total="$1"
    if [[ "$1" -ge "60" ]];then
        Total="$(($Total-60))"
        if [[ "$1" -ge "60" ]];then
            AddmoreM="$Total"
            OptimizeMinute "$Total"
        else
            echo $AddmoreM
            AddmoreM=""
        fi
    else
        echo ${1}
    fi
}

# OptimizeHour(){
#     [[ -z "$Addmore" ]] && Addmore=""
#     local Total="$1"
#     if [[ "$1" -ge "24" ]];then
#         Total="$(($Total-24))"
#         if [[ "$1" -ge "24" ]];then
#             Addmore="$Total"
#             OptimizeHour "$Total"
#         else
#             echo $Addmore
#             Addmore=""
#         fi
#     else
#         echo ${1}
#     fi
# }

grep_prop(){
  local REGEX="s/^$1=//p"
  shift
  local FILES=$@
  [ -z "$FILES" ] && FILES="$MPATH/module.prop"
  cat $FILES 2>/dev/null | dos2unix | sed -n "$REGEX" | head -n 1
}

WriteSysKernel(){
    local listConfig
    local file
    local value
    for listConfig in ${@}
    do
        file="$(echo "$listConfig" | awk -F ':' '{print $1}')"
        value="$(echo "$listConfig" | awk -F ':' '{print $2}')"
        [[ ! -z "$file" ]] && [[ ! -z "$value" ]] && WriteTo "$value" "/proc/sys/kernel/$file"
    done
    GetErrorMsg "WriteSysKernel"
} 2>>$RLOGsE

WriteSysVm(){
    local listConfig
    local file
    local value
    for listConfig in ${@}
    do
        file="$(echo "$listConfig" | awk -F ':' '{print $1}')"
        value="$(echo "$listConfig" | awk -F ':' '{print $2}')"
        [[ ! -z "$file" ]] && [[ ! -z "$value" ]] && WriteTo "$value" "/proc/sys/vm/$file"
    done
    GetErrorMsg "WriteSysVm"
} 2>>$RLOGsE

WriteOnly(){
    local write="n"
    if [[ ! -z "${2}" ]] && [[ "${2}" != *"$MPATH"* ]];then
        if [[ -f "${2}" ]];then
            if echo "${1}" > "${2}" 2>/dev/null
            then
                write="y"
            fi
        fi
        SendWriteStatus "${1}" "${2}" "$write"
    else
        if echo "${1}" > "${2}" 2>/dev/null
        then
            write="y"
        fi
        SendWriteStatus "${1}" "${2}" "$write"
    fi
    GetErrorMsg "WriteOnly"
} 2>>$RLOGsE

WriteTo(){
    local write="n"
    if [[ ! -z "$2" ]] && [[ -f "$2" ]];then
        chmod 0666 "$2"  2>/dev/null
        if echo "$1" > "$2" 2>/dev/null
        then
            write="y"
        fi
        SendWriteStatus "$1" "$2" "$write"
    fi
    GetErrorMsg "WriteTo"
} 2>>$RLOGsE

WriteLockTo(){
    local write="n"
    if [[ ! -z "$2" ]] && [[ -f "$2" ]];then
        chmod 0666 "$2" 2>/dev/null
        if echo "$1" > "$2" 2>/dev/null
        then
            write="y"
        fi
        chmod 0444 "$2" 2>/dev/null
        SendWriteStatus "$1" "$2" "$write"
    fi
    GetErrorMsg "WriteLockTo"
} 2>>$RLOGsE

SendWriteStatus(){
    if [[ "$FullDebug" == "on" ]];then
        if [[ "${3}" == "y" ]];then
            SendWLogs "${1} → ${2}"
        else
            SendWLogs "Failed:${1} → ${2}"
        fi
    fi
}

GetConfigVar(){
    for asu in $@
    do
        first=$(echo $asu | awk -F ':' '{print $1}')
        second=$(echo $asu | awk -F ':' '{print $2}')
        if [[ -z "$second" ]];then
            Beforesecond="$Beforesecond' '$first"
            eval Var_$BeforeFirst="$Beforesecond"
        else
            eval Var_$first="$second"
            echo Var_$first
            BeforeFirst=$first
            Beforesecond=$second
        fi
        first=""
        second=""
    done
    BeforeFirst=""
    Beforesecond=""
}

MultiplyForInt()
{
    local GetValue="$(echo "$1" | bc)"
    local CleanValue="$(echo "$GetValue" | awk -F '.' '{print $1}')"
    echo "$CleanValue"
}

ActiveZram(){
    local GetTotalSize="$(MultiplyForInt "$2*1024*1024")"
    $GetBusyBox swapoff "/dev/block/$1"
    echo "1" > "/sys/block/$1/reset"
    echo "$GetTotalSize" > "/sys/block/$1/disksize"
    $GetBusyBox mkswap "/dev/block/$1"
    $GetBusyBox swapon "/dev/block/$1"
    if [[ $GetTotalSize != $(cat /sys/block/$1/disksize) ]];then
        WriteOnly "-1" $PMConfig/zram_ext.conf
        WriteOnly "-1" $PMConfig/zram_ext.conf
        ConfigValueZram="-1"
        ConfigValueZramExt="-1"
    fi
}

SetupZram(){
    local ConfigValueZram=$(cat $PMConfig/zram.conf)
    local ConfigValueZramExt=$(cat $PMConfig/zram_ext.conf)
    local SetZramSize="$(getprop persist.miui.extm.bdsize)"
    local FromMiui="y"
    if [[ "$ConfigValueZram" -gt "0" ]];then    
        FromMiui="n"
        SetZramSize="$(MultiplyForInt "$ConfigValueZram*1024")"
    fi
    if [[ -e /dev/block/zram0 ]]&& [[ "$(cat /sys/block/zram0/disksize)" != "$(MultiplyForInt "$SetZramSize*1024*1024")" ]];then
        if [[ ! -z "$SetZramSize" ]] && [[ "$SetZramSize" -gt "0" ]];then
            ActiveZram "zram0" "$SetZramSize"
            if [[ "$FromMiui" == "y" ]];then
                [[ "$NoLogs" == "n" ]] && SendLogs "Setup ZRAM($SetZramSize) from miui done"
            else
                [[ "$NoLogs" == "n" ]] && SendLogs "Setup custom ZRAM($SetZramSize) done"
            fi
        fi
    fi
    if [[ "$ConfigValueZramExt" == "-1" ]];then
        if [[ -e /dev/block/zram1 ]] || [[ -e /dev/block/zram2 ]] || [[ -e /dev/block/zram3 ]] || [[ -e /dev/block/zram4 ]];then
            WriteOnly "0" $PMConfig/zram_ext.conf
        fi
    elif [[ "$ConfigValueZramExt" == "0" ]];then
        if [[ ! -e /dev/block/zram1 ]] || [[ ! -e /dev/block/zram2 ]] || [[ ! -e /dev/block/zram3 ]] || [[ ! -e /dev/block/zram4 ]];then
            WriteOnly "-1" $PMConfig/zram_ext.conf
        fi
    elif [[ "$ConfigValueZramExt" -gt "0" ]];then
        SetZramSize="$(MultiplyForInt "$ConfigValueZramExt*1024")"
        ZramFixedSize="$(MultiplyForInt "$SetZramSize*1024*1024")"
        local TheLoop=""
        local UpdateDone="n"
        for TheLoop in 1 2 3 4
        do
            [[ -e /dev/block/zram${TheLoop} ]] && [[ "$(cat /sys/block/zram${TheLoop}/disksize)" != "$(MultiplyForInt "$SetZramSize*1024*1024")" ]] && ActiveZram "zram${TheLoop}" "$ZramFixedSize" && UpdateDone="y"
        done
        if [[ "$UpdateDone" == "n" ]];then
            WriteOnly "-1" $PMConfig/zram_ext.conf
        else
            [[ "$NoLogs" == "n" ]] && SendLogs "Setup extra ZRAM($SetZramSize) done"
        fi
    fi
    GetErrorMsg "SetupZram"
} 2>>$RLOGsE