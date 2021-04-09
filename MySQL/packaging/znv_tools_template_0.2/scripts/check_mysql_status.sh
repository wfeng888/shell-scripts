#! /bin/bash

cur_dir=$(cd `dirname $0`;pwd)
source ${cur_dir}/set_param.sh 
port=$1
max_gap=1200
#mysql=${SUB_MYSQL_BASE}/bin/mysql
sec_behind=
null_string='NULL'
msg=
operation='CHECK_SLAVE_STATUS'
#db_dir=${SUB_PREFIX_DATA_PATH}

msg_gap_too_large='the current mysql has gap %s seconds .'
msg_gap_is_null='the show slave status with NULL sec_behind . maybe slave threads is not running.please check!'
#ops_username="autoOPS"

sec_behind=`$mysql --login-path=${port} -u${ops_username} -e "show  slave status \G " |grep -i 'Seconds_Behind_Master'|cut -d ":" -f 2 `
[ ${sec_behind:-NULL} = ${null_string} ]  &&  msg=${msg_gap_is_null} 
[ ${sec_behind:-NULL} != ${null_string} ] && [  ${sec_behind:0} -gt ${max_gap} ] && msg=${msg_gap_too_large/%s/${sec_behind}}
[  "${msg}" ] && ${cur_dir}/send_mail.sh "need attention!" ${operation} "$port" "${msg}"
