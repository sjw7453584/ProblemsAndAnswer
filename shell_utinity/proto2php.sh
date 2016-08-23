#!/bin/bash
src_file='client.proto'
des_file='op_cmd/op_cmd.php'
server_src_file='server.proto'
common_src_file='common.proto'
gm_common_src_file='gm_common.proto'
log_src_file='log.proto'
msg_c_arry=(cl lc la al ca ac gc cg  dg gd ge eg ed de go eo do ag ga mt tm me em)

for item in ${msg_c_arry[@]}
do
msg=`cat ${src_file} | grep "message *${item}_.*"|sed 's/message //g'|sed 's/\(.*\)/\\\\"\1\\\\",/'`
echo client msg: ${msg}
msg_server=`cat ${server_src_file} | grep "message *${item}_.*"|sed 's/message //g'|sed 's/\(.*\)/\\\\"\1\\\\",/'`
msg_common=`cat ${common_src_file} | grep "message *${item}_.*"|sed 's/message //g'|sed 's/\(.*\)/\\\\"\1\\\\",/'`
msg_gm_common=`cat ${gm_common_src_file} | grep "message *${item}_.*"|sed 's/message //g'|sed 's/\(.*\)/\\\\"\1\\\\",/'`
msg_log=`cat ${log_src_file} | grep "message *${item}_.*"|sed 's/message //g'|sed 's/\(.*\)/\\\\"\1\\\\",/'`

msg+=${msg_server}
msg+=${msg_common}
msg+=${msg_gm_common}
msg+=${mgs_log}
echo final msg: ${msg}
msg=`echo ${msg} |sed  "s/ /######!!!!/g"`
msg=`echo ${msg} |sed  "s/\"${item}_/!!!!######${item}_/g"`
sed -i "/${item}_list/,/);/c\\${item}_list = arrary\(\n${msg}\n\);" ${des_file}
done

sed -i 's/######!!!!/\n/g' ${des_file}
sed -i 's/!!!!######/\t\"/g' ${des_file}

