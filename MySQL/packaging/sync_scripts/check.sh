#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd) 
source ${cur_dir}/set_param.sh
if ! [  -x "${mysql}"  -a  -f "${mysql}" ] ; then
	tar -xzpf "${cur_dir}/${mysql_gz_software}" -C "${cur_dir}" > /dev/null 2>&1
fi
[ `check_mysql_alive` -gt 0 ] && echo "Error: mysql is not running !" && exit 1
exit 0