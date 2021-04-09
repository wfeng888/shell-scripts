#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd) 
source ${cur_dir}/set_param.sh
have_done="${cur_dir}/have_done_${cur_time}"
cat /dev/null > ${have_done}
if ! [  -x "${mysql}"  -a  -f "${mysql}" ] ; then
	tar -xzpf "${cur_dir}/${mysql_gz_software}" -C "${cur_dir}" > /dev/null 2>&1
fi
[ `check_mysql_alive` -gt 0 ] && echo "Error: mysql is not running !" && exit 1
while read filename
do
exec_sql "source ${cur_dir}/${filename}"
check_sql_exec_result
if [ $? -eq 0 ] ; then 
    echo "$filename" >> ${have_done}
else
    [ `echo "${ignore_error}X"|tr a-z A-Z` != 'YX' ] && echo "$filename install failed ! " && exit 1
fi
done<${list_file}
exit 0