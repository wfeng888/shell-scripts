#!/bin/bash
INTERVAL=20
DIR=/root/lockwait

mkdir -p $DIR
sql1='select * from (
SELECT r.trx_wait_started AS wait_started, TIMEDIFF(NOW(), r.trx_wait_started) AS wait_age, TIMESTAMPDIFF(SECOND, r.trx_wait_started, NOW()) AS wait_age_secs, rl.lock_table AS locked_table,
       rl.lock_index AS locked_index,
       rl.lock_type AS locked_type,
       r.trx_id AS waiting_trx_id,
       r.trx_started as waiting_trx_started,
       TIMEDIFF(NOW(), r.trx_started) AS waiting_trx_age,
       r.trx_rows_locked AS waiting_trx_rows_locked,
       r.trx_rows_modified AS waiting_trx_rows_modified,
       r.trx_mysql_thread_id AS waiting_pid,
       r.trx_query AS waiting_query,
       rl.lock_id AS waiting_lock_id,
       rl.lock_mode AS waiting_lock_mode,
       b.trx_id AS blocking_trx_id,
       b.trx_mysql_thread_id AS blocking_pid,b.trx_query AS blocking_query,bl.lock_id AS blocking_lock_id,bl.lock_mode AS blocking_lock_mode,b.trx_started AS blocking_trx_started,TIMEDIFF(NOW(), b.trx_started) AS blocking_trx_age,b.trx_rows_locked AS blocking_trx_rows_locked,b.trx_rows_modified AS blocking_trx_rows_modified
  FROM information_schema.innodb_lock_waits w
       INNER JOIN information_schema.innodb_trx b    ON b.trx_id = w.blocking_trx_id
       INNER JOIN information_schema.innodb_trx r    ON r.trx_id = w.requesting_trx_id
       INNER JOIN information_schema.innodb_locks bl ON bl.lock_id = w.blocking_lock_id
       INNER JOIN information_schema.innodb_locks rl ON rl.lock_id = w.requested_lock_id
) n
 where n.wait_age_secs > 10
 ORDER BY n.wait_started'
 
sql2='select  THREAD_ID,EVENT_ID,EVENT_NAME,CURRENT_SCHEMA,SQL_TEXT from performance_schema.events_statements_history_long cn  where exists (select  1  from information_schema.innodb_lock_waits w,information_schema.innodb_trx b,performance_schema.threads c where w.blocking_trx_id = b.trx_id and b.trx_mysql_thread_id = c.PROCESSLIST_ID and  cn.THREAD_ID = c.THREAD_ID ) order by THREAD_ID,EVENT_ID'
while true; do
  check_query=$(echo "$sql1"| mysql    -uroot -pzxm10 --socket=/database/my3000/var/3000.socket  -A -Bs )
  if [ "${check_query}" ] ; then
    timestamp=$(date +%s)
    echo "$check_query" > $DIR/innodb_lockwait_report_${timestamp}
    echo "#########################################################" >> $DIR/innodb_lockwait_report_${timestamp}
    echo "$sql2" |mysql  -uroot -pzxm10 --socket=/database/my3000/var/3000.socket -A -Bs  >> $DIR/innodb_lockwait_report_${timestamp}
  fi

  sleep $INTERVAL
done