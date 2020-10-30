#! /bin/bash
oper=$1
login_path=$2
mysqld_safe=${SUB_MYSQL_BASE}/bin/mysqld_safe
db_dir=${SUB_PREFIX_DATA_PATH}
mysql=${SUB_MYSQL_BASE}/bin/mysql
socketf=
ops_username="autoOPS"
case "$oper" in 
   start)
       ${mysqld_safe} --defaults-file=${db_dir}/my.cnf &
       ;;
   stop)
       ${mysql} --login-path=${login_path} -u${ops_username} -e 'set global innodb_fast_shutdown=0; shutdown ;' 
       ;;
   *)
       echo "usage: $0 start|stop passwd "
       exit 2
       ;;
esac;

