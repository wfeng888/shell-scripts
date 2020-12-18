#!/bin/bash

usage(){
	local local_usage="Usage: hadoop_oper.sh start|stop|format  all|namenode|datanode|resourcemanager|nodemanager|proxyserver|historyserver  [cluster_name]"
	echo "${local_usage}"
}


check_between(){
local i=1
first_param=
[ ! $1 ] && echo 1 && return 
for arg in $*
do
[  ${i} -eq 1 ] && first_param=`echo ${arg}|tr "a-z" "A-Z"` && let "i+=1" && continue
[  `echo ${arg}| tr "a-z" "A-Z"` == ${first_param} ] && echo 0 && return;
let "i+=1"
done
echo 1
}

sudo_exec(){
if [ ${os_user} == ${1} ] ; then
	$2
else
	sudo -E -u${1} $2
fi
if [ $?  -eq 0 ] ; then
echo "success ${oper} ${target}"
else
echo "failed to  ${oper} ${target}"
fi
}

oper_hdfs(){
sudo_exec "${user_hdfs}"  "$HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs ${oper} ${target}"
}

oper_yarn(){
sudo_exec "${user_yarn}"  "$HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR ${oper} ${target} "
}

oper_mapred(){
sudo_exec "${user_mapred}"  "$HADOOP_PREFIX/sbin/mr-jobhistory-daemon.sh --config $HADOOP_CONF_DIR ${oper} ${target} "
}

format_hdfs(){
# Format a new distributed filesystem as hdfs 
sudo_exec "${user_hdfs}"  "$HADOOP_PREFIX/bin/hdfs namenode -format ${clustername}"
}


oper=$1
target=$2
clustername=$3
user_hdfs="hdfs"
user_yarn="yarn"
user_mapred="mapred"
os_user=`id -un`

cpwd=$(cd `dirname $0`;pwd)

# if no args specified, show usage
if [ $# -le 1  -o  `check_between ${oper} start stop format` -eq 1  -o `check_between ${target}  all namenode datanode resourcemanager nodemanager proxyserver historyserver `  -eq 1  ]; then
  usage
  exit 1
fi

if [ -r  $cpwd/set_env.sh ] ; then
	source $cpwd/set_env.sh
fi

case $target in 
all)
mid_target=${target}
for l_target in namenode datanode 
do
	target=${l_target}
	oper_hdfs
done
for l_target in resourcemanager nodemanager proxyserver 
do
	target=${l_target}
	oper_yarn
done
target=historyserver
oper_mapred
;;
namenode|datanode)
oper_hdfs
;;
resourcemanager|nodemanager|proxyserver)
oper_yarn
;;
historyserver)
oper_mapred
;;
format)
format_hdfs
;;
*)
    usage
    ;;
esac