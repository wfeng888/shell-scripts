#! /bin/bash
cur_dir=$(cd `dirname $0`;pwd)
source ${cur_dir}/set_param.sh

[  `check_between  ${cur_user}  ${os_user_root}  ${os_user_es}` -eq 1 ]  && echo "execute user must be elasticsearch or root ! " && exit 1;

check_port_busy ${http_port}
[ $? -ne 0 ] && echo " http_port ${http_port} is busy or sudo failed, exit with errors .please check !" && exit 1
check_port_busy ${transport_tcp_port}
[ $? -ne 0 ] && echo " transport_tcp_port ${transport_tcp_port} is busy or sudo failed, exit with errors  .please check !" && exit 1
( [ "${network_host}X" == "X"  ] || [ "${transport_host}X" == "X"  ]  || [ "${http_host}X" == "X"  ]  ) && echo "network_host or transport_host or http_host is null , it must be not null. " && exit 1
exit 0