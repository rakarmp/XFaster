#!/system/bin/sh
#
# its me zyarexx
# SPDX-License-Identifier: GPL-3.0-or-later
#
## just get somethings

MiD="$(cat /system/etc/XCore/info/modules_id.info)"
MPATH="$(cat /system/etc/XCore/info/magisk_path)/$MiD"
PMConfig="$MPATH/system/etc/XCore/configs"
LOGs=$MPATH/system/etc/XCore/info/logs.log
LOGsE=$MPATH/system/etc/XCore/info/logs_error.log
RLOGsE=$MPATH/system/etc/XCore/info/logs_error.log
# MODULE_STATUS="$(cat $MPATH/system/etc/XCore/configs/status.conf)"
MODULE_STATUS="1"

## get gpu type
MALIGPU="n"
TypeGpu='Undetected / Unknow'
if [[ -d /sys/class/kgsl/kgsl-3d0 ]]; then
    NyariGPU="/sys/class/kgsl/kgsl-3d0"
    TypeGpu="Adreno"
elif [[ -d /sys/devices/platform/kgsl-3d0.0/kgsl/kgsl-3d0 ]]; then
    NyariGPU="/sys/devices/platform/kgsl-3d0.0/kgsl/kgsl-3d0"
    TypeGpu="Adreno"
elif [[ -d /sys/devices/soc/*.qcom,kgsl-3d0/kgsl/kgsl-3d0 ]]; then
    NyariGPU="/sys/devices/soc/*.qcom,kgsl-3d0/kgsl/kgsl-3d0"
    TypeGpu="Adreno"
elif [[ -d /sys/devices/soc.0/*.qcom,kgsl-3d0/kgsl/kgsl-3d0 ]]; then
    NyariGPU="/sys/devices/soc.0/*.qcom,kgsl-3d0/kgsl/kgsl-3d0"
    TypeGpu="Adreno"
elif [[ -d /sys/devices/platform/*.gpu/devfreq/*.gpu ]]; then
    NyariGPU=/sys/devices/platform/*.gpu/devfreq/*.gpu
elif [[ -d /sys/devices/platform/*.mali ]]; then
    NyariGPU=/sys/devices/platform/*.mali
    MALIGPU="y"
    TypeGpu="Mali"
elif [[ -d /sys/class/misc/mali0 ]]; then
    NyariGPU=/sys/class/misc/mali0
    MALIGPU="y"
    TypeGpu="Mali"
else
    NyariGPU='';
fi

TypeCpu="$(cat /proc/cpuinfo | grep Hardware | awk -F ": " '{print $2}')"
# if [[ "$TypeCpu" == *"Qualcomm Technologies, Inc"* ]];then
#     TypeCpu=${TypeCpu/"Qualcomm Technologies, Inc "/""}
# fi
# if [[ "$TypeCpu" == *"/"* ]];then
#     TypeCpu="$(echo $TypeCpu | awk -F "/" '{print $1}')"
# fi

## misc
GoTurbo="0"
GoNormal="0"
StopScanGameList="n"
LastDropCache=""
ScreenState="on"
CurrentDisplayStatus="on"
FullDebug="on"
DoSilentWrite="0"
SwitchForceDoze="0"
CpuChangeFail="0"
CPUFREQLOCKSTATUS="n"
CPUFREQLOCKSTATUSSLEEP="n"
ThermalServiceStatus="Y"