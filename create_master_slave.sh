#!/bin/bash -e
# Parameters
#!/bin/bash

#set OG_SUBNET,GS_PASSWORD,MASTER_IP,SLAVE_1_IP,MASTER_HOST_PORT,MASTER_LOCAL_PORT,SLAVE_1_HOST_PORT,SLAVE_1_LOCAL_PORT,MASTER_NODENAME,SLAVE_NODENAME

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

read -p "Please input OG_SUBNET (容器所在网段) [172.11.0.0/24]: " OG_SUBNET
OG_SUBNET=${OG_SUBNET:-172.11.0.0/24}
echo "OG_SUBNET set $OG_SUBNET"

read -p "Please input GS_PASSWORD (定义数据库密码)[Enmo@123]: " GS_PASSWORD
GS_PASSWORD=${GS_PASSWORD:-Enmo@123}
echo "GS_PASSWORD set $GS_PASSWORD"

read -p "Please input SHARED_DATA_DIR（共享数据目录）[/mnt/cephfs/]" SHARED_DATA_DIR
SHARED_DATA_DIR=${SHARED_DATA_DIR:-/mnt/cephfs/}
echo "SHARED_DATA_DIR set $SHARED_DATA_DIR"

read -p "Please input network name (容器网络名字)[opengaussnetwork]: " NETWORK_NAME
NETWORK_NAME=${NETWORK_NAME:-opengaussnetwork}
echo "NETWORK_NAME set $NETWORK_NAME"

read -p "Please input MASTER_IP (主库IP)[172.11.0.101]: " MASTER_IP
MASTER_IP=${MASTER_IP:-172.11.0.101}
echo "MASTER_IP set $MASTER_IP"

read -p "Please input SLAVE_1_IP (备库IP)[172.11.0.102]: " SLAVE_1_IP
SLAVE_1_IP=${SLAVE_1_IP:-172.11.0.102}
echo "SLAVE_1_IP set $SLAVE_1_IP"

read -p "Please input MASTER_HOST_PORT (主库数据库服务端口)[5432]: " MASTER_HOST_PORT
MASTER_HOST_PORT=${MASTER_HOST_PORT:-5432}
echo "MASTER_HOST_PORT set $MASTER_HOST_PORT"

read -p "Please input MASTER_LOCAL_PORT (主库通信端口)[5434]: " MASTER_LOCAL_PORT
MASTER_LOCAL_PORT=${MASTER_LOCAL_PORT:-5434}
echo "MASTER_LOCAL_PORT set $MASTER_LOCAL_PORT"

read -p "Please input MASTER_CONFIG_PATH（主库配置文件路径）[/mnt/cephfs/og1]" MASTER_CONFIG_PATH
MASTER_CONFIG_PATH=${MASTER_CONFIG_PATH:-/mnt/cephfs/og1}
echo "MASTER_CONFIG_PATH set $MASTER_CONFIG_PATH"

read -p "Please input SLAVE_1_HOST_PORT (备库数据库服务端口)[6432]: " SLAVE_1_HOST_PORT
SLAVE_1_HOST_PORT=${SLAVE_1_HOST_PORT:-6432}
echo "SLAVE_1_HOST_PORT set $SLAVE_1_HOST_PORT"

read -p "Please input SLAVE_1_LOCAL_PORT (备库通信端口)[6434]: " SLAVE_1_LOCAL_PORT
SLAVE_1_LOCAL_PORT=${SLAVE_1_LOCAL_PORT:-6434}
echo "SLAVE_1_LOCAL_PORT set $SLAVE_1_LOCAL_PORT"

read -p "Please input SLAVE_1_CONFIG_PATH（主库配置文件路径）[/mnt/cephfs/og2]" SLAVE_1_CONFIG_PATH
SLAVE_1_CONFIG_PATH=${SLAVE_1_CONFIG_PATH:-/mnt/cephfs/og2}
echo "SLAVE_1_CONFIG_PATH set $SLAVE_1_CONFIG_PATH"

read -p "Please input MASTER_NODENAME [opengauss_master]: " MASTER_NODENAME
MASTER_NODENAME=${MASTER_NODENAME:-opengauss_master}
echo "MASTER_NODENAME set $MASTER_NODENAME"

read -p "Please input SLAVE_NODENAME [opengauss_slave1]: " SLAVE_NODENAME
SLAVE_NODENAME=${SLAVE_NODENAME:-opengauss_slave1}
echo "SLAVE_NODENAME set $SLAVE_NODENAME"

read -p "Please input openGauss VERSION [1.0.1]: " VERSION
VERSION=${VERSION:-1.0.1}
echo "openGauss VERSION set $VERSION"

echo "starting  "

docker network create --subnet=$OG_SUBNET $NETWORK_NAME \
|| {
  echo ""
  echo "ERROR: OpenGauss Database Network was NOT successfully created."
  echo "HINT: opengaussnetwork Maybe Already Exsist Please Execute 'docker network rm opengaussnetwork' "
  exit 1
}
echo "OpenGauss Database Network Created."

if [[ ! -d $SHARED_DATA_DIR ]]; then
    mkdir -p $SHARED_DATA_DIR
fi

if [[ ! -d $MASTER_CONFIG_PATH ]]; then
    mkdir -p $MASTER_CONFIG_PATH
fi


if [[ ! -d $SLAVE_1_CONFIG_PATH ]]; then
    mkdir -p $SLAVE_1_CONFIG_PATH
fi

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
