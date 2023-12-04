#!/system/bin/sh
#
# its me zyarexx
# SPDX-License-Identifier: GPL-3.0-or-later
#
{
    # Warning

    if [[ "$RunModules" -ge "1" ]];then

        StopGetDisplay="n"

        FullDebug="on"

        CheckFileConfig

        CpuTweakModeOff="$(cat $PMConfig/use_cpu_tweak.conf | awk -F ":" '{print $1}')"
        [[ -z "$CpuTweakModeOff" ]] && CpuTweakModeOff="0"
        CpuTweakModeOn="$(cat $PMConfig/use_cpu_tweak.conf | awk -F ":" '{print $2}')"
        [[ -z "$CpuTweakModeOn" ]] && CpuTweakModeOn="0"

        if [[ ! -z "$1" ]] && [[ "$1" == "boot" ]];then
            FirstBootMsg
            BackupConfig
            sleep 1s
            FullDebug="off"
            SetOff
            CpuInpuBoostUpdate "off"
            UpdateGov write "$PMConfig/gov_off.conf"
            DoCpuTweak "$CpuTweakModeOff"
            FullDebug="on"
            UpdateFastCharging
            CpuFreqLock "Boot"
        fi

        if [[ "$BOOTmode" = "0" ]];then
            DoFstrim

            DoSqlite

            DoDropCache

            if [[ -f /sys/class/thermal/thermal_message/sconfig ]] && [[ "$(cat /sys/class/thermal/thermal_message/sconfig)" != "$(cat $PMConfig/sconfig.thermal.conf)" ]] && [[ "(cat $PMConfig/sconfig.thermal.lock.conf)" == "1" ]];then
                WriteLockTo "$(cat $PMConfig/sconfig.thermal.conf)" /sys/class/thermal/thermal_message/sconfig
            fi

            if [[ "$StopScanGameList" == "n" ]];then
                RegenGameList
                StopScanGameList="Y"
            fi

            ### set model based gpu usage
            if [[ "$MODULE_STATUS" == "1" ]];then
                ## call some files
                MinGpuUsage="$(cat $PMConfig/min_gpu_usage.conf)"
                MaxGpuUsage="$(cat $PMConfig/max_gpu_usage.conf)"
                MaxCheckGpuUsage="$(cat $PMConfig/max_check_gpu_usage.conf)"
                ModuleMode="$(cat $PMConfig/modules_mode.conf)"

                ## call some function
                GetStatusGpu
                GetActiveAppName
                CheckCurrentApp

                ## check status module
                if [[ "$ModuleMode" == "Force On" ]];then
                    ## force on
                    GoTurbo="$MaxCheckGpuUsage"
                    GoNormal="0"
                elif [[ "$ModuleMode" == "Force Off" ]];then
                    ## force off
                    GoNormal="$MaxCheckGpuUsage"
                    GoTurbo="0"
                elif [[ "$ModuleMode" == "Depend App" ]];then
                    ## depend app
                    if [[ "$GameDetected" == "y" ]];then
                        GoTurbo="$MaxCheckGpuUsage" && GoNormal="0"
                    else
                        GoNormal="$MaxCheckGpuUsage" && GoTurbo="0"
                    fi
                elif [[ "$ModuleMode" == "Depend GPU Usage" ]];then
                    ## Depend GPU Usage
                    if [[ "$GpuStatus" -ge "$MaxGpuUsage" ]] && [[ "$RunModules" == "1" ]] && [[ "$GoTurbo" -le "$MaxCheckGpuUsage" ]];then
                        GoTurbo=$(($GoTurbo+1))
                        [[ "$GoNormal" -ge "0" ]] && GoNormal=$(($GoNormal-1))
                    elif [[ "$GpuStatus" -le "$MinGpuUsage" ]] && [[ "$RunModules" == "2" ]] && [[ "$GoNormal" -le "$MaxCheckGpuUsage" ]];then
                        GoNormal=$(($GoNormal+1))
                        [[ "$GoTurbo" -ge "0" ]] && GoTurbo=$(($GoTurbo-1))
                    fi
                elif [[ "$ModuleMode" == "Display Status" ]];then
                    ## Depend Display Status
                    if [[ "$(GetDisplayStatus)" == "on" ]] && [[ "$RunModules" == "1" ]] && [[ "$GoTurbo" -le "$MaxCheckGpuUsage" ]];then
                        GoTurbo="$MaxCheckGpuUsage"
                        GoNormal="0"
                    elif [[ "$(GetDisplayStatus)" == "off" ]] && [[ "$RunModules" == "2" ]] && [[ "$GoNormal" -le "$MaxCheckGpuUsage" ]];then
                        GoNormal="$MaxCheckGpuUsage"
                        GoTurbo="0"
                    fi
                else
                    ## auto
                    [[ "$ModuleMode" != "Auto" ]] && WriteOnly "Auto" $PMConfig/modules_mode.conf

                    if [[ "$GpuStatus" -ge "$MaxGpuUsage" ]] && [[ "$RunModules" == "1" ]] && [[ "$GoTurbo" -le "$MaxCheckGpuUsage" ]];then
                        GoTurbo=$(($GoTurbo+1))
                        [[ "$GoNormal" -ge "0" ]] && GoNormal=$(($GoNormal-1))
                    elif [[ "$GpuStatus" -le "$MinGpuUsage" ]] && [[ "$RunModules" == "2" ]] && [[ "$GoNormal" -le "$MaxCheckGpuUsage" ]];then
                        GoNormal=$(($GoNormal+1))
                        [[ "$GoTurbo" -ge "0" ]] && GoTurbo=$(($GoTurbo-1))
                    fi

                    [[ "$GameDetected" == "y" ]] && GoTurbo="$MaxCheckGpuUsage" && GoNormal="0"

                fi

                if [[ "$(GetDisplayStatus)" == "off" ]] && [[ "$RunModules" == "2" ]];then
                    GoTurbo="0"
                    GoNormal="$MaxCheckGpuUsage"
                fi

                if [[ "$GoTurbo" -ge "$MaxCheckGpuUsage" ]] && [[ "$RunModules" == "1" ]];then
                    SetOn
                    CpuInpuBoostUpdate "on"
                    UpdateGov write "$PMConfig/gov_on.conf"
                    DoCpuTweak "$CpuTweakModeOn"
                    GoTurbo="0"
                    GoNormal="0"
                elif [[ "$GoNormal" -ge "$MaxCheckGpuUsage" ]] && [[ "$RunModules" == "2" ]];then
                    if [[ "$GameDetected" == "n" ]];then
                        SetOff
                        CpuInpuBoostUpdate "off"
                        UpdateGov write "$PMConfig/gov_off.conf"
                        DoCpuTweak "$CpuTweakModeOff"
                    fi
                    GoTurbo="0"
                    GoNormal="0"
                else
                    if [[ "$(cat $PMConfig/silent_overwrite.conf)" == "1" ]];then
                        if [[ "$RunModules" == "2" ]] && [[ "$DoSilentWrite" == "3" ]];then
                            FullDebug="off"
                            SetOn "silent"
                            DoCpuTweak "$CpuTweakModeOn"
                            FullDebug="on"
                            DoSilentWrite="0"
                        else
                            DoSilentWrite=$(($DoSilentWrite+1))
                        fi
                    fi
                fi

                if [[ "$GoTurbo" -ge "$MaxCheckGpuUsage" ]] || [[ "$GoTurbo" -le "0" ]];then
                    GoTurbo="0"
                fi
                if [[ "$GoNormal" -ge "$MaxCheckGpuUsage" ]] || [[ "$GoNormal" -le "0" ]];then
                    GoNormal="0"
                fi

                if [[ "$RunModules" == "2" ]];then
                    sleep $(cat $PMConfig/wait_when_on.conf)s
                else
                    if [[ "$(GetDisplayStatus)" == "off" ]];then
                        sleep $(($(cat $PMConfig/wait_when_off.conf)*2))s
                    else
                        sleep $(cat $PMConfig/wait_when_off.conf)s
                    fi
                fi
            fi

            ## set mtk cpu mode
            if [[ "$RunModules" == "2" ]];then
                [[ -f $PMConfig/mtk_cpu_mode_on.conf ]] && MTKSwitchCpuMode "$PMConfig/mtk_cpu_mode_on.conf"
                CpuFreqLock "Lock"
            else
                [[ -f $PMConfig/mtk_cpu_mode_off.conf ]] && MTKSwitchCpuMode "$PMConfig/mtk_cpu_mode_off.conf"
                CpuFreqLock "Unlock"
            fi

            SetForceDoze
        fi
    fi
    SetupZram
    GetErrorMsg "MainProcess"
} 2>>$RLOGsE
