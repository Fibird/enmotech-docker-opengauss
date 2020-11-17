BASEDIR=$(dirname $0)
. ${BASEDIR}/config

docker rm -f serverless-metadata-db
docker network rm $NETWORK_NAME

rm -rf $DB_DATA_DIR

