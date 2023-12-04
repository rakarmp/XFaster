# its me zyarexx

echo 'Apa Hahh!!' > /dev/null

Warning(){
local passCodeA="N"
local passCodeB="N"
local passCodeC="N"
local passCodeD="N"
local passCodeE="N"
local Continue="N"
if [[ ! -z "$LaQuilla" ]] && [[ "$LaQuilla" == "Luximine" ]];then
passCodeA="Y"
fi
if [[ ! -z "$LfonTex" ]] && [[ "$LfonTex" == "LaQuilla" ]];then
passCodeB="Y"
fi
if [[ ! -z "$HuaHiax" ]] && [[ "$HuaHiax" == "LfonTex" ]];then
passCodeC="Y"
fi
if [[ ! -z "$Luximine" ]] && [[ "$Luximine" == "HuaHiax" ]];then
passCodeD="Y"
fi
if [[ ! -z "$RemovexThis" ]] && [[ "$RemovexThis" == "y" ]];then
passCodeE="Y"
fi
if [[ "$passCodeA" == "Y" ]] && [[ "$passCodeB" == "Y" ]] && [[ "$passCodeC" == "Y" ]] && [[ "$passCodeD" == "Y" ]] && [[ "$passCodeE" == "Y" ]];then
Continue="Y"
fi
if [[ "$Continue" == "N" ]];then
local ngentod
for ngentod in last_fstrim.log last_optimize_database.log logs.log logs_error.log optimize_database.log write.log;do
echo "Ga mungkin Nyala" > $MPATH/system/etc/XCore/info/$ngentod
done
echo "Because ${passCodeA}${passCodeB}${passCodeC}${passCodeD}${passCodeE}${Continue}" > "$MPATH/system/etc/XCore/info/reason_broken.log"
echo "0" > "$MPATH/system/etc/XCore/configs/status.conf"
fi
}
