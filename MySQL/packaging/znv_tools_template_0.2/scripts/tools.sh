#! /bin/bash
keepalived_pid=
send_singal=
signal_name_reload='RELOAD'
signal_name_stop='STOP'
signal_name_data='DATA'
signal_name_stats='STATS'
operation=`echo $1 | tr '[a-z]' '[A-Z]' `
cpwd=$(cd `dirname $0`; pwd)
keepalived_pid_file="${cpwd}/../var/keepalived.pid"
readonly signal_name_reload  signal_name_stop signal_name_data signal_name_stats  keepalived_pid_file


[ -e ${keepalived_pid_file} ] && keepalived_pid=`cat ${keepalived_pid_file} `
( [ -z ${keepalived_pid} ] || [ -z `ps -ef|grep keepalived|sed 's/ \{1,\}/ /g'|cut -d ' ' -f 2|grep ${keepalived_pid}` ] ) &&  echo " process not running !"  && exit 1 ;
case "$operation" in
    RELOAD)
        send_singal=` keepalived --signum=${signal_name_reload} ` 
        ;;
    STOP)
        send_singal=` keepalived --signum=${signal_name_stop} `
        ;;
    DATA)
        send_singal=` keepalived --signum=${signal_name_data} `
        ;;
    STATS)
        send_singal=` keepalived --signum=${signal_name_stats} `
        ;;
    *)
        echo $"Usage: $0 {stop|data|stats||reload}"
        exit 2;
	;;
esac
[ -n ${send_singal} ] && kill -${send_singal} ${keepalived_pid}
[ $? -eq 0 ] && echo "success !"  && exit 0;
echo " failure !";
exit 1;
