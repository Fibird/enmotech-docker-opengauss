#!/bin/bash
 
 
docker run --network serverless_network --ip 175.11.0.103 --privileged=true \
--name test_master -h test_master -p 8303:8303 -d \
-e GS_PORT=8303 \
-e OG_SUBNET=175.11.0.0/24 \
-e GS_PASSWORD=Enmo@123 \
-e NODE_NAME=test_master \
-v /mnt/test/:/var/lib/opengauss \
-v /mnt/test/master_config/postgresql.conf:/etc/opengauss/postgresql.conf \
fibird/opengauss:1.0.1 -M primary \
-c 'config_file=/etc/opengauss/postgresql.conf'
