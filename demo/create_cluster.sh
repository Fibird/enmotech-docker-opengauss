#!/bin/bash

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} -n cluster-name -N network -c slave-count...
Create a serverless opengauss cluster.
      -h, --help		display help and exit
      -n, --name		set name of opengauss cluster
      -N, --network		set the network of opengauss cluster
      -c, --count		set count of slave database 
      -d, --directory		set the shared data directory of opengauss cluster
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
SHORT=n:N:c:d:h
LONG=name:,network:,count:,help

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
    -N|--network)
      network="$2"
      shift 2
      ;;
    -c|--count)
      slave_count="$2"
      shift 2
      ;;
    -d|--directory)
      shared_data_dir=$2
      shift 2
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

if [[ -z "$shared_data_dir" ]]; then
    echo "shared data directory cannot be null!"
    show_help
    exit -1
fi

if [[ -z "$slave_count" ]]; then
    echo "slave count cannot be null!"
    show_help
    exit -1
fi

if [[ -z "$network" ]]; then
    echo "network of cluster cannot be null!"
    show_help
    exit -1
fi

if [[ ! -d $shared_data_dir ]]; then
    echo "directory $shared_data_dir is not exist!"
    exit -1
fi

docker network create --subnet=$network "$name-network"


GS_PORT=$MASTER_HOST_PORT
SERVER_MODE=primary
REPL_CONN_INFO="replconninfo1 = 'localhost=$MASTER_IP localport=$MASTER_LOCAL_PORT localservice=$MASTER_HOST_PORT remotehost=$SLAVE_1_IP remoteport=$SLAVE_1_LOCAL_PORT remoteservice=$SLAVE_1_HOST_PORT'\n" 
NODE_NAME=$MASTER_NODENAME
CONFIG_PATH=$MASTER_CONFIG_PATH
opengauss_setup_postgresql_conf

docker run --network $NETWORK_NAME --ip $MASTER_IP --privileged=true \
--name $MASTER_NODENAME -h $MASTER_NODENAME -p $MASTER_HOST_PORT:$MASTER_HOST_PORT -d \
-e GS_PORT=$MASTER_HOST_PORT \
-e OG_SUBNET=$OG_SUBNET \
-e GS_PASSWORD=$GS_PASSWORD \
-e NODE_NAME=$MASTER_NODENAME \
-e REPL_CONN_INFO="replconninfo1 = 'localhost=$MASTER_IP localport=$MASTER_LOCAL_PORT localservice=$MASTER_HOST_PORT remotehost=$SLAVE_1_IP remoteport=$SLAVE_1_LOCAL_PORT remoteservice=$SLAVE_1_HOST_PORT'\n" \
-v $SHARED_DATA_DIR:/var/lib/opengauss \
-v $MASTER_CONFIG_PATH/postgresql.conf:/etc/opengauss/postgresql.conf \
fibird/opengauss:$VERSION -M primary \
-c 'config_file=/etc/opengauss/postgresql.conf' \
|| {
  echo ""
  echo "ERROR: OpenGauss Database Master Docker Container was NOT successfully created."
  exit 1
}
echo "OpenGauss Database Master Docker Container created."

sleep 30s

GS_PORT=$SLAVE_1_HOST_PORT
SERVER_MODE=standby
REPL_CONN_INFO="replconninfo1 = 'localhost=$SLAVE_1_IP localport=$SLAVE_1_LOCAL_PORT localservice=$SLAVE_1_HOST_PORT remotehost=$MASTER_IP remoteport=$MASTER_LOCAL_PORT remoteservice=$MASTER_HOST_PORT'\n" \
NODE_NAME=$SLAVE_NODENAME
CONFIG_PATH=$SLAVE_1_CONFIG_PATH
opengauss_setup_postgresql_conf

docker run --network $NETWORK_NAME --ip $SLAVE_1_IP --privileged=true \
--name $SLAVE_NODENAME -h $SLAVE_NODENAME -p $SLAVE_1_HOST_PORT:$SLAVE_1_HOST_PORT -d \
-e GS_PORT=$SLAVE_1_HOST_PORT \
-e OG_SUBNET=$OG_SUBNET \
-e GS_PASSWORD=$GS_PASSWORD \
-e NODE_NAME=$SLAVE_NODENAME \
-e REPL_CONN_INFO="replconninfo1 = 'localhost=$SLAVE_1_IP localport=$SLAVE_1_LOCAL_PORT localservice=$SLAVE_1_HOST_PORT remotehost=$MASTER_IP remoteport=$MASTER_LOCAL_PORT remoteservice=$MASTER_HOST_PORT'\n" \
-v $SHARED_DATA_DIR:/var/lib/opengauss \
-v $SLAVE_1_CONFIG_PATH/postgresql.conf:/etc/opengauss/postgresql.conf \
fibird/opengauss:$VERSION -M standby \
-c 'config_file=/etc/opengauss/postgresql.conf' \
|| {
  echo ""
  echo "ERROR: OpenGauss Database Slave1 Docker Container was NOT successfully created."
  exit 1
}
echo "OpenGauss Database Slave1 Docker Container created."
