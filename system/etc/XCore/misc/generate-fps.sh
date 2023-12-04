#!/system/bin/sh
#
# its me zyarexx
# SPDX-License-Identifier: GPL-3.0-or-later
#
CleanString(){
    local data="$(echo -e "$@" )"
    local CLeanKramnel
    local c
    local Get
    local max="${#data}"
    for i in $(seq 0 $max)
    do
        c=${data:$i:1}
        Get="$(printf "\&#%d;" "'$c")"
        if [[ "$Get" != *"#0;"* ]];then
            CLeanKramnel="${CLeanKramnel}${Get}";
        fi
    done
    echo "$CLeanKramnel"
}
ServiceFps(){
    local MiDx="$(cat /system/etc/XCore/info/modules_id.info)"
    local MPATHx="$(cat /system/etc/XCore/info/magisk_path)/$MiDx"
    local ScanFPS="$(cat $MPATHx/system/etc/XCore/configs/get_fps.conf)"
    local StatFPSPath="$MPATHx/system/etc/XCore/configs/get_fps_status.conf"
    local StatFPS="1"
    [[ ! -d /sdcard/zycfps ]] && mkdir /sdcard/zycfps
    local AppName="$(dumpsys activity recents | grep 'Recent #0' | awk -F 'A=' '{ print $2 }' | awk -F ' ' '{ print $1 }')"
    local TypeDetect="Part-C"
    if [[ "$AppName" == *":"* ]] ;then
        AppName="$(echo "$AppName" | awk -F ':' '{ print $2 }')"
    fi
    if [[ "$AppName" == *"apex "* ]] ;then
        AppName=""
    fi
    local FindFPsPath="$(find /sys -name *measured_fps* | grep "c-0")"
    if [[ -z "$FindFPsPath" ]];then
        FindFPsPath="$(find /sys -name *display_framerate_main*)"
        [[ ! -z "$FindFPsPath" ]] && TypeDetect="Part-B"
    else
        TypeDetect="Part-A"
    fi
    TypeDetect="Part-C"
    local TimeNya="$(date +"%Y%m%d-%H%M%S")"
    local FileName="GetFps-$AppName-$TimeNya.html"
    local TFName="Fps-$AppName-$TimeNya.raw"
    local FCName="FrameCount-$AppName-$TimeNya.raw"
    local TName="Time-$AppName-$TimeNya.raw"
    local CTName="Cpu-$AppName-$TimeNya.raw"
    local CTLName="CpuLabel-$AppName-$TimeNya.raw"
    local BTName="Battery-$AppName-$TimeNya.raw"
    echo "" > /sdcard/zycfps/$TFName
    echo "" > /sdcard/zycfps/$TName
    echo "" > /sdcard/zycfps/$CTName
    echo "" > /sdcard/zycfps/$CTLName
    echo "" > /sdcard/zycfps/$BTName
    echo "" > /sdcard/zycfps/$FCName
    echo "1" > $StatFPSPath
    local FindBatteryTempPath=""
    local FindCpuTempPath=""
    local Checker="$(cat /sys/class/thermal/thermal_zone*/type)"
    local TypeX="0"
    if [[ "$Checker" == *"cpu"* ]] && [[ "$Checker" == *"cpus"* ]] && [[ "$Checker" == *"cpu-1"* ]];then
        TypeX="1"
    elif [[ "$Checker" == *"cpu"* ]] ;then
        TypeX="2"
    fi
    for asu in $(seq 1 80)
    do
        if [[ -e /sys/class/thermal/thermal_zone$asu/type ]];then
            GetType="$(cat /sys/class/thermal/thermal_zone$asu/type)"
            if [[ "$GetType" == *"battery"* ]];then
                FindBatteryTempPath="/sys/class/thermal/thermal_zone$asu/temp"
            fi
            if [[ "$TypeX" == "1" ]];then
                if [[ "$GetType" == *"cpu"* ]] && [[ "$GetType" != *"cpus"* ]] && [[ "$GetType" == *"cpu-1"* ]];then
                    FindCpuTempPath="${FindCpuTempPath}/sys/class/thermal/thermal_zone$asu "
                fi
            elif [[ "$TypeX" == "2" ]];then
                if [[ "$GetType" == *"cpu"* ]];then
                    FindCpuTempPath="${FindCpuTempPath}/sys/class/thermal/thermal_zone$asu "
                fi
            else
                FindCpuTempPath="${FindCpuTempPath}/sys/class/thermal/thermal_zone$asu "
            fi
        fi
    done

    local CTemp="1000"
    local no=0;
    local FirstTime="y"
    local initial
    local GetFps
    local GetFrameCount
    local Aa
    local Bb
    [[ "$TypeDetect" != "Part-A" ]] && CTemp="10"
    while [[ $ScanFPS == 1 ]]
    do
        StatFPS=$(cat $StatFPSPath)
        if [[ "$StatFPS" == "1" ]];then
            no=$(($no+1))
            result="$(cat $FindFPsPath)"
            if [[ "$TypeDetect" == "Part-A" ]];then
                GetFps="$(echo $result | awk -F " " '{print $2}' | awk -F "." '{print $1}')"
                GetFrameCount="$(echo $result | awk -F " " '{print $4}' | awk -F ":" '{print $2}')"
                GetFps="$(echo $GetFps | awk -F " " '{print $1}')"
                GetFrameCount="$(echo $GetFrameCount | awk -F " " '{print $1}')"
            elif [[ "$TypeDetect" == "Part-B" ]];then
                GetFps="$(echo $result | awk -F " " '{print $1}')"
            else
                Aa="$(service call SurfaceFlinger 1013 | grep -o -E \([a-fA-F0-9]+\ \))"
                Aa="$(echo $(( 16#$Aa )))"
                sleep 1
                Bb="$(service call SurfaceFlinger 1013 | grep -o -E \([a-fA-F0-9]+\ \))"
                Bb="$(echo $(( 16#$Bb )))"
                GetFps="$(($Bb-$Aa))"
            fi
            if [[ "$FirstTime" == "y" ]];then
                echo "$GetFps" > /sdcard/zycfps/$TFName
                [[ "$TypeDetect" == "Part-A" ]] && echo "$GetFrameCount" > /sdcard/zycfps/$FCName
                echo "$(date +"%H:%M:%S")" > /sdcard/zycfps/$TName
                echo "$(cat $FindBatteryTempPath)" > /sdcard/zycfps/$BTName
            else
                echo "$(cat /sdcard/zycfps/$TFName) $GetFps" > /sdcard/zycfps/$TFName
                [[ "$TypeDetect" == "Part-A" ]] && echo "$(cat /sdcard/zycfps/$FCName) $GetFrameCount" > /sdcard/zycfps/$FCName
                echo "$(cat /sdcard/zycfps/$TName) $(date +"%H:%M:%S")" > /sdcard/zycfps/$TName
                echo "$(cat /sdcard/zycfps/$BTName) $(cat $FindBatteryTempPath)" > /sdcard/zycfps/$BTName
            fi
            initial="y"
            for asu in $FindCpuTempPath
            do
                if [[ $no -le 1 ]];then
                    if [[ "$FirstTime" == "y" ]];then
                        echo "$(cat $asu/type)" > /sdcard/zycfps/$CTLName
                    else
                        echo "$(cat /sdcard/zycfps/$CTLName) $(cat $asu/type)" > /sdcard/zycfps/$CTLName
                    fi
                fi
                if [[ "$initial" == 'y' ]];then
                    if [[ "$FirstTime" == "y" ]];then
                        echo "$(cat $asu/temp)" > /sdcard/zycfps/$CTName
                    else
                        echo "$(cat /sdcard/zycfps/$CTName) $(cat $asu/temp)" > /sdcard/zycfps/$CTName
                    fi
                else
                    echo "$(cat /sdcard/zycfps/$CTName):$(cat $asu/temp)" > /sdcard/zycfps/$CTName
                fi
                initial="n"
                FirstTime="n"
            done
            [[ "$TypeDetect" != "Part-C" ]] && sleep 1s
            ScanFPS="$(cat $MPATHx/system/etc/XCore/configs/get_fps.conf)"
        fi
    done

    local Kver="$(cat /proc/version)"
    local TFNameVal="$(cat /sdcard/zycfps/$TFName)"
    local TNameVal="$(cat /sdcard/zycfps/$TName)"
    local CTNameVal="$(cat /sdcard/zycfps/$CTName)"
    local CTLNameVal="$(cat /sdcard/zycfps/$CTLName)"
    local BTNameVal="$(cat /sdcard/zycfps/$BTName)"
    local FCNameVal="$(cat /sdcard/zycfps/$FCName)"
    [[ -e /system/etc/XCore/misc/display.html ]] && cp -af /system/etc/XCore/misc/display.html /sdcard/zycfps/$FileName
    [[ -e /sdcard/display.html ]] && cp -af /sdcard/display.html /sdcard/zycfps/$FileName
    sed -i "s/BashTInfoBash--/$(CleanString "$AppName")/" /sdcard/zycfps/$FileName
    sed -i "s/BashKInfoBash--/$(CleanString "$Kver")/" /sdcard/zycfps/$FileName
    sed -i "s/BashTFNameBash--/$TFNameVal/" /sdcard/zycfps/$FileName
    sed -i "s/BashTNameBash--/$TNameVal/" /sdcard/zycfps/$FileName
    sed -i "s/BashCTNameBash--/$CTNameVal/" /sdcard/zycfps/$FileName
    sed -i "s/BashCTLNameBash--/$CTLNameVal/" /sdcard/zycfps/$FileName
    sed -i "s/BashBTNameBash--/$BTNameVal/" /sdcard/zycfps/$FileName
    sed -i "s/BashFCNameBash--/$FCNameVal/" /sdcard/zycfps/$FileName
    sed -i "s/BashCTempBash--/$CTemp/" /sdcard/zycfps/$FileName

    rm -rf /sdcard/zycfps/$TFName /sdcard/zycfps/$FCName /sdcard/zycfps/$TName /sdcard/zycfps/$CTName /sdcard/zycfps/$CTLName /sdcard/zycfps/$BTName
}

MiDx="$(cat /system/etc/XCore/info/modules_id.info)"
MPATHx="$(cat /system/etc/XCore/info/magisk_path)/$MiDx"
GetConf="$(cat $MPATHx/system/etc/XCore/configs/get_fps.conf)"
RunnerXD=1
while [[ "$RunnerXD" == "1" ]]
do
    if [[ "$GetConf" == "1" ]];then
        ServiceFps
    fi
    sleep 1s
    GetConf="$(cat $MPATHx/system/etc/XCore/configs/get_fps.conf)"
done