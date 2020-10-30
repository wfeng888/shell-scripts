#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd) 
source ${cur_dir}/set_param.sh
have_done="${cur_dir}/have_done_${cur_time}"
cat /dev/null > ${have_done}
while read filename
do
echo $filename
sh ${cur_dir}/recreate.sh "${cur_dir}/$filename" "$sync_es_http_ip"  "$sync_es_http_port"
if [ $? -eq 0 ] ; then 
    echo "$filename" >> ${have_done}
else
    echo "$filename install failed, abort! "
    exit 1
fi
done<${list_file}
exit 0