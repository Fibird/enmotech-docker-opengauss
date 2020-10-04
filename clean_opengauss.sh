docker stop opengauss_master
docker rm opengauss_master
docker stop opengauss_slave1
docker rm opengauss_slave1

docker network rm opengaussnetwork
