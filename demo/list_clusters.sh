#!/bin/bash

BASEDIR=$(dirname $0)
. ${BASEDIR}/config

docker run -it --network serverless_network --rm mysql mysql -h $DB_SERVER_NAME -uroot -pmy-secret-pw -D serverless_db -e "select * from metadata;"

#list -n 
