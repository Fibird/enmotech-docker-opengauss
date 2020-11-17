#!/bin/bash


BASEDIR=$(dirname $0)
. ${BASEDIR}/config

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
SHORT=n:c:d:h
LONG=name:,count:,directory:,help

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

if [[ ! -d $shared_data_dir ]]; then
    echo "directory $shared_data_dir is not exist!"
    exit -1
fi

#docker network create --subnet=$SLS_SUBNET $NETWORK_NAME

array=(${SLS_SUBNET//// })  
network=${array[0]}
echo $network

array=(${network//./ })  
echo ${array[@]}

network_prefix=${array[0]}.${array[1]}.${array[2]}
host_num=${array[3]}

echo "query database..."
server_num=$(docker run -it --network serverless_network --rm mysql mysql -h $DB_SERVER_NAME -uroot -p$DB_PWD -D serverless_db -e "select count(*) from metadata;" | grep -E "[0-9]+" | awk '{print $2}')
if [[ "$server_num" -eq 0 ]]; then
    cluster_id=0
else
    cluster_id=$(docker run -it --network serverless_network --rm mysql mysql -h $DB_SERVER_NAME -uroot -p$DB_PWD -D serverless_db -e "select cluster_id from metadata order by cluster_id desc LIMIT 1;" | grep -E "[0-9]+" | awk '{print $2}')
fi

echo cluster_id:$cluster_id
