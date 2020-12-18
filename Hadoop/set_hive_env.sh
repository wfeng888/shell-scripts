#!/bin/bash
export HIVE_HOME=/usr/local/apache-hive-stable
export PATH=$HIVE_HOME/bin:$PATH
export HADOOP_HOME=/usr/local/hadoop-stable
export HIVE_CONF_DIR=/home/bigdata/apache-hive/hive1/conf
export HIVE_OPTS="--hiveconf system:java.io.tmpdir=/home/bigdata/apache-hive/hive1/tmp"