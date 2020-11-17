SLAVE_1_IP=172.11.0.108
SLAVE_NODENAME=opengauss_slave7
SLAVE_1_HOST_PORT=7532
SLAVE_1_LOCAL_PORT=7534
MASTER_HOST_PORT=5432
MASTER_LOCAL_PORT=5434
MASTER_IP=172.11.0.101
VERSION=1.0.1
GS_PASSWORD=Enmo@123 
OG_SUBNET=172.11.0.0/24
SHARED_DATA_DIR=/mnt/test4/
SLAVE_1_CONFIG_PATH=/mnt/test4/og8/


docker run --network opengaussnetwork --ip $SLAVE_1_IP --privileged=true \
--name $SLAVE_NODENAME -h $SLAVE_NODENAME -p $SLAVE_1_HOST_PORT:$SLAVE_1_HOST_PORT -d \
-e GS_PORT=$SLAVE_1_HOST_PORT \
-e OG_SUBNET=$OG_SUBNET \
-e GS_PASSWORD=$GS_PASSWORD \
-e NODE_NAME=$SLAVE_NODENAME \
-e REPL_CONN_INFO="replconninfo1 = 'localhost=$SLAVE_1_IP localport=$SLAVE_1_LOCAL_PORT localservice=$SLAVE_1_HOST_PORT remotehost=$MASTER_IP remoteport=$MASTER_LOCAL_PORT remoteservice=$MASTER_HOST_PORT'\n" \
-v $SHARED_DATA_DIR:/var/lib/opengauss \
-v $SLAVE_1_CONFIG_PATH/postgresql.conf:/etc/opengauss/postgresql.conf \
enmotech/opengauss:$VERSION -M standby \
-c 'config_file=/etc/opengauss/postgresql.conf' \
|| {
  echo ""
  echo "ERROR: OpenGauss Database Slave1 Docker Container was NOT successfully created."
  exit 1
}
echo "OpenGauss Database Slave1 Docker Container created."
