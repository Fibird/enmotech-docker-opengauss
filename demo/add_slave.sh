#!/bin/bash

BASEDIR=$(dirname $0)
. ${BASEDIR}/config

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} -n cluster-name 
Create a serverless opengauss cluster.
      -h, --help		display help and exit
      -n, --name		set name of opengauss cluster
EOF
}

# append parameter to postgres.conf for connections
opengauss_setup_postgresql_conf() {
	wget https://gitee.com/opengauss/openGauss-server/raw/1.0.0/src/common/backend/utils/misc/postgresql.conf.sample -O $CONFIG_PATH/postgresql.conf
        {
                echo
                if [ -n "$GS_PORT" ]; then
                    echo "password_encryption_type = 0"
                    echo "port = $GS_PORT"
                else
                    echo '# use default port 5432'
                    echo "password_encryption_type = 0"
                fi
                
                if [ -n "$SERVER_MODE" ]; then
                    echo "listen_addresses = '0.0.0.0'"
                    echo "most_available_sync = on"
                    echo "remote_read_mode = non_authentication"
                    echo "pgxc_node_name = '$NODE_NAME'"
                    echo "synchronous_commit = off"
                    # echo "application_name = '$NODE_NAME'"
                    if [ "$SERVER_MODE" = "primary" ]; then
                        echo "max_connections = 100"
                    else
                        echo "max_connections = 100"
                    fi
                    echo -e "$REPL_CONN_INFO"
                    if [ -n "$SYNCHRONOUS_STANDBY_NAMES" ]; then
                        echo "synchronous_standby_names=$SYNCHRONOUS_STANDBY_NAMES"
                    fi
                else
                    echo "listen_addresses = '*'"
                fi

                if [ -n "$OTHER_PG_CONF" ]; then
                    echo -e "$OTHER_PG_CONF"
                fi 
        } >> "$CONFIG_PATH/postgresql.conf"
}

getopt --test > /dev/null
if [[ $? -ne 4 ]]
then
  echo "Error:`getopt --test` failed in this environment."
  exit 1
fi

# Options of this tool
SHORT=n:h
LONG=name:,help

# Use getopt tool to parse options from users
PARSED=$(getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@")
if [[ $? -ne 0 ]]
then
  show_help
  exit 2
fi

eval set -- "$PARSED"

while true; do
  case "$1" in
    -h|--help)
      shift
      ;;
    -n|--name)
      name="$2"
      shift 2
      ;;
    --)       # End of all options
      shift
      break
      ;;
    *)
      exit 3
      ;;
  esac
done

if [[ -z "$name" ]]; then
    echo "name of cluster cannot be null!"
    show_help
    exit -1
fi

result_pair=$(docker run -it --network serverless_network --rm mysql mysql -h $DB_SERVER_NAME -uroot -p$DB_PWD -D serverless_db -e "select * from metadata where cluster_name = '$name';" | grep -E "[0-9]+")

master_ip=$(echo $result_pair | awk '{print $6}')
slave_count=$(echo $result_pair | awk '{print $8}')
#echo slave_count:$slave_count
shared_data_dir=$(echo $result_pair | awk '{print $10}')
master_host_port=$(echo $result_pair | awk '{print $12}')
master_local_port=$((master_host_port+2))
password=$(echo $result_pair | awk '{print $14}')

slave_num=$((slave_count+1))
#echo slave_num:$slave_num
slave_node_name="$name"_slave"$slave_num"
slave_host_port=$((master_host_port+slave_num*100))
slave_local_port=$((slave_host_port+2))

array=(${master_ip//./ })  
network_prefix=${array[0]}.${array[1]}.${array[2]}
host_num=${array[3]}

slave_ip=$network_prefix.$((host_num+slave_num))
#echo $slave_ip

GS_PORT=$slave_host_port
SERVER_MODE=standby
REPL_CONN_INFO="replconninfo1 = 'localhost=$slave_ip localport=$slave_local_port localservice=$slave_host_port remotehost=$master_ip remoteport=$master_local_port remoteservice=$master_host_port'\n" \
NODE_NAME=$slave_node_name
CONFIG_PATH=$shared_data_dir/slave"$slave_num"_config
if [[ ! -d $CONFIG_PATH ]]; then
    mkdir -p $CONFIG_PATH
fi
opengauss_setup_postgresql_conf

docker run --network $NETWORK_NAME --ip $slave_ip --privileged=true \
--name $slave_node_name -h $slave_node_name -p $slave_host_port:$slave_host_port -d \
-e GS_PORT=$slave_host_port \
-e OG_SUBNET=$SLS_SUBNET \
-e GS_PASSWORD=password \
-e NODE_NAME=$slave_node_name \
-e REPL_CONN_INFO="replconninfo1 = 'localhost=$slave_ip localport=$slave_local_port localservice=$slave_host_port remotehost=$master_ip remoteport=$master_local_port remoteservice=$master_host_port'\n" \
-v $shared_data_dir:/var/lib/opengauss \
-v $CONFIG_PATH/postgresql.conf:/etc/opengauss/postgresql.conf \
$OG_REPO/opengauss:$VERSION -M standby \
-c 'config_file=/etc/opengauss/postgresql.conf' \
|| {
  echo ""
  echo "ERROR: OpenGauss Database Slave1 Docker Container was NOT successfully created."
  exit 1
}
echo "OpenGauss Database Slave$slave_num Docker Container created."

docker run -it --network serverless_network --rm mysql mysql -h $DB_SERVER_NAME -uroot -p$DB_PWD -D serverless_db -e "update metadata set slave_count = $slave_num where cluster_name = '$name';"


