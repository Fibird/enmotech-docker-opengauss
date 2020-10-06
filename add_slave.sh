SLAVE_1_IP=172.11.0.103
SLAVE_NODENAME=opengauss_slave2
SLAVE_1_HOST_PORT=7432
SLAVE_1_LOCAL_PORT=7434
MASTER_HOST_PORT=5432
MASTER_LOCAL_PORT=5434
MASTER_IP=172.11.0.101
VERSION=1.0.1
GS_PASSWORD=Enmo@123 
OG_SUBNET=172.11.0.0/24


docker run --network opengaussnetwork --ip $SLAVE_1_IP --privileged=true \
--name $SLAVE_NODENAME -h $SLAVE_NODENAME -p $SLAVE_1_HOST_PORT:$SLAVE_1_HOST_PORT -d \
-e GS_PORT=$SLAVE_1_HOST_PORT \
-e OG_SUBNET=$OG_SUBNET \
-e GS_PASSWORD=$GS_PASSWORD \
-e NODE_NAME=$SLAVE_NODENAME \
-e REPL_CONN_INFO="replconninfo1 = 'localhost=$SLAVE_1_IP localport=$SLAVE_1_LOCAL_PORT localservice=$SLAVE_1_HOST_PORT remotehost=$MASTER_IP remoteport=$MASTER_LOCAL_PORT remoteservice=$MASTER_HOST_PORT'\n" \
enmotech/opengauss:$VERSION -M standby \
|| {
  echo ""
  echo "ERROR: OpenGauss Database Slave1 Docker Container was NOT successfully created."
  exit 1
}
echo "OpenGauss Database Slave1 Docker Container created."
