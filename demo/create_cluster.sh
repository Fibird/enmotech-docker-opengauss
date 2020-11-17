#!/bin/bash


BASEDIR=$(dirname $0)
. ${BASEDIR}/config

# Usage info
show_help() {
cat << EOF
Usage: ${0##*/} -n cluster-name -c slave-count -d shared-data-directory
Create a serverless opengauss cluster.
      -h, --help		display help and exit
      -n, --name		set name of opengauss cluster
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

array=(${network//./ })  

network_prefix=${array[0]}.${array[1]}.${array[2]}
host_num=${array[3]}

echo "query database..."
server_num=$(docker run -it --network serverless_network --rm mysql mysql -h $DB_SERVER_NAME -uroot -p$DB_PWD -D serverless_db -e "select count(*) from metadata;" | grep -E "[0-9]+" | awk '{print $2}')
if [[ "$server_num" -eq 0 ]]; then
    cluster_id=0
else
    cluster_id=$(docker run -it --network serverless_network --rm mysql mysql -h $DB_SERVER_NAME -uroot -p$DB_PWD -D serverless_db -e "select cluster_id from metadata order by cluster_id desc LIMIT 1;" | grep -E "[0-9]+" | awk '{print $2}')
    ((cluster_id++))
fi

echo cluster_id:$cluster_id

master_host_num=$((host_num+MAX_SLAVE_COUNT+MAX_SLAVE_COUNT*cluster_id))
master_ip="$network_prefix.$master_host_num"
master_host_port=$((PORT_START+cluster_id*100))
master_local_port=$((master_host_port+2))
master_node_name="$name"_master

slave_1_ip=$network_prefix.$((master_host_num+1))
slave_1_host_port=$((master_host_port+1000))
slave_1_local_port=$((slave_1_host_port+2))


GS_PORT=$master_host_port
SERVER_MODE=primary
REPL_CONN_INFO="replconninfo1 = 'localhost=$master_ip localport=$master_local_port localservice=$master_host_port remotehost=$slave_1_ip remoteport=$slave_1_local_port remoteservice=$slave_1_host_port'\n" 
NODE_NAME=$master_node_name
CONFIG_PATH=$shared_data_dir/master_config
if [[ ! -d $CONFIG_PATH ]]; then
    mkdir -p $CONFIG_PATH
fi
opengauss_setup_postgresql_conf

echo $NETWORK_NAME,$master_ip,$NODE_NAME,$master_host_port,$master_local_port,$SLS_SUBNET,$GS_PASSWORD
docker run --network $NETWORK_NAME --ip $master_ip --privileged=true \
--name $NODE_NAME -h $NODE_NAME -p $master_host_port:$master_host_port -d \
-e GS_PORT=$master_host_port \
-e OG_SUBNET=$SLS_SUBNET \
-e GS_PASSWORD=$GS_PASSWORD \
-e NODE_NAME=$NODE_NAME \
-e REPL_CONN_INFO="replconninfo1 = 'localhost=$master_ip localport=$master_local_port localservice=$master_host_port remotehost=$slave_1_ip remoteport=$slave_1_local_port remoteservice=$slave_1_host_port'\n" \
-v $shared_data_dir:/var/lib/opengauss \
-v $CONFIG_PATH/postgresql.conf:/etc/opengauss/postgresql.conf \
$og_repo/opengauss:$VERSION -M primary \
-c 'config_file=/etc/opengauss/postgresql.conf' \
|| {
  echo ""
  echo "ERROR: OpenGauss Database Master Docker Container was NOT successfully created."
  exit 1
}
echo "OpenGauss Database Master Docker Container created."

sleep 30s

slave_host_port=$master_host_port
# create slaves db
for ((i=1;i<=$slave_count;i++)); do
	slave_ip=$network_prefix.$((master_host_num+i))
	slave_host_port=$((slave_host_port+100))
	slave_local_port=$((slave_host_port+2))
	GS_PORT=$slave_host_port
	SERVER_MODE=standby
	REPL_CONN_INFO="replconninfo1 = 'localhost=$slave_ip localport=$slave_local_port localservice=$slave_host_port remotehost=$master_ip remoteport=$master_local_port remoteservice=$master_host_port'\n" \
	NODE_NAME="$name"_slave"$i"
	CONFIG_PATH=$shared_data_dir/slave"$i"_config

	if [[ ! -d $CONFIG_PATH ]]; then
	    mkdir -p $CONFIG_PATH
	fi
	opengauss_setup_postgresql_conf

	docker run --network $NETWORK_NAME --ip $slave_ip --privileged=true \
	--name $NODE_NAME -h $NODE_NAME -p $slave_host_port:$slave_host_port -d \
	-e GS_PORT=$slave_host_port \
	-e OG_SUBNET=$SLS_SUBNET \
	-e GS_PASSWORD=$GS_PASSWORD \
	-e NODE_NAME=$NODE_NAME \
	-e REPL_CONN_INFO="replconninfo1 = 'localhost=$slave_ip localport=$slave_local_port localservice=$slave_host_port remotehost=$master_ip remoteport=$master_local_port remoteservice=$master_host_port'\n" \
	-v $shared_data_dir:/var/lib/opengauss \
	-v $CONFIG_PATH/postgresql.conf:/etc/opengauss/postgresql.conf \
	$og_repo/opengauss:$VERSION -M standby \
	-c 'config_file=/etc/opengauss/postgresql.conf' \
	|| {
	  echo ""
	  echo "ERROR: OpenGauss Database Slave1 Docker Container was NOT successfully created."
	  exit 1
	}
	echo "OpenGauss Database Slave$i Docker Container created."
done

create_time=$(date +%Y%m%d%H%M%S)

docker run -it --network serverless_network --rm mysql mysql -h $DB_SERVER_NAME -uroot -p$DB_PWD -D serverless_db -e "insert into metadata(cluster_name, master_ip, slave_count, shared_data_dir, master_port, create_time) values('$name', '$master_ip', $slave_count, '$shared_data_dir', $master_host_port, '$create_time');"


