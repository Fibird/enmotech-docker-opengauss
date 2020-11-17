#!/bin/bash

BASEDIR=$(dirname $0)
. ${BASEDIR}/config

# create data dir
if [[ ! -d $DB_DATA_DIR ]]; then
    mkdir -p $DB_DATA_DIR
fi

docker network create --subnet=$SLS_SUBNET $NETWORK_NAME \
|| {
  echo ""
  echo "ERROR: Serverless Network was NOT successfully created."
  echo "HINT: $NETWORK_NAME Maybe Already Exsist Please Execute 'docker network rm $NETWORK_NAME' "
  exit 1
}
echo "Serverless Network Created."


# start database
docker run --network $NETWORK_NAME --name=$DB_SERVER_NAME --restart=always -v $DB_DATA_DIR:/var/lib/mysql  --ip $DB_IP -p $DB_PORT:$DB_PORT -e MYSQL_ROOT_PASSWORD=$DB_PWD -d mysql:latest

sleep 30

# reference: https://www.jianshu.com/p/e6d54cf405af
# init database
docker run -it --network serverless_network --rm mysql mysql -h $DB_SERVER_NAME -uroot -p$DB_PWD -e "create database serverless_db; use serverless_db; create table metadata(cluster_id int primary key AUTO_INCREMENT, cluster_name varchar(36), master_ip varchar(16), slave_count int unsigned, shared_data_dir varchar(128), master_port int unsigned, password varchar(32), create_time date);"

