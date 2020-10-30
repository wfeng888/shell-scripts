#!/bin/bash

mysql_port=${SUB_PORT}
systemctl stop mysql_${mysql_port}.service
exit $?