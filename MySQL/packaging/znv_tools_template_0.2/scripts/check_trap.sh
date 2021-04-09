#! /bin/bash
cur_dir=$(cd `dirname $0`;pwd)
source ${cur_dir}/set_param.sh 
basedir=${cur_dir}/..
#mysql=${SUB_MYSQL_BASE}/bin/mysql
haIgnore=${basedir}/config/ha.ignore
port=$1
#db_dir=${SUB_PREFIX_DATA_PATH}
#ops_username="autoOPS"
stopping(){
PROLOGUE=$(echo "$(date +"%a %b %e %X %Y")": \[$PPID:$$\])
echo "$PROLOGUE" STOPPING
}


trap "stopping; exit 0;"  HUP INT QUIT USR1 USR2 PIPE ALRM 
if [ -f ${haIgnore} ]; then
   exit 0
fi
flag=`$mysql --login-path=${port} -u${ops_username} -e "select 1 flag from dual; "|grep -v flag `
flag=${flag:-0}
if [  "$flag" -a $flag -eq  1 ];then 
	exit 0
else 
	exit 1
fi;
