#!/bin/bash
cur_dir=$(cd `dirname $0`;pwd) 
source ${cur_dir}/predefine.sh


pname_mysql_software_base="mysql_software_base"
pname_mysql="mysql_path"
pname_mysqld_safe="mysqld_safe"
pname_db_dir="db_dir"
pname_backup_base_dir="backup_base_dir"
pname_expire_days="expire_days"



mysql_software_base=`get_value  ${pname_mysql_software_base}  ${config_file}`
mysql=`get_value  ${pname_mysql}  ${config_file}`
[ "${mysql}X" == "X" ] && mysql="${mysql_software_base}/bin/mysql"
mysqld_safe=`get_value  ${pname_mysqld_safe}  ${config_file}`
[ "${mysqld_safe}X" == "X" ] && mysqld_safe="${mysql_software_base}/bin/mysqld_safe"
db_dir=`get_value  ${pname_db_dir}  ${config_file}`
backup_base_dir=`get_value  ${pname_backup_base_dir}  ${config_file}`
expire_days=`get_value  ${pname_expire_days}  ${config_file}`



ops_username="autoOPS"