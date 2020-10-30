#!/bin/bash

mysql_port=${SUB_PORT}
systemctl start mysql_${mysql_port}.service
exit $?