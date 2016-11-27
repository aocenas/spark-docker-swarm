#!/usr/bin/env bash
set -evx

REGION=eu-west-1
ZONE=c
CLUSTER_PREFIX=spark-cluster
MASTER_TYPE=m4.large
WORKER_TYPE=m3.medium
SPOT_PRICE=0.067
NUM_WORKERS=1
SPARK_IMAGE=gettyimages/spark:2.0.2-hadoop-2.7

DRIVER_OPTIONS="\
--driver amazonec2 \
--amazonec2-security-group=default \
--amazonec2-vpc-id $VPC_ID \
--amazonec2-zone $ZONE \
--amazonec2-region $REGION"

MASTER_OPTIONS="$DRIVER_OPTIONS \
--engine-label role=master \
--amazonec2-instance-type=$MASTER_TYPE"

MASTER_MACHINE_NAME=${CLUSTER_PREFIX}-master
docker-machine create $MASTER_OPTIONS $MASTER_MACHINE_NAME

MASTER_IP=$(aws ec2 describe-instances --output json | jq -r \
".Reservations[].Instances[] | select(.KeyName==\"$MASTER_MACHINE_NAME\" and .State.Name==\"running\") | .PrivateIpAddress")
docker-machine ssh $MASTER_MACHINE_NAME sudo docker swarm init --advertise-addr $MASTER_IP
TOKEN=$(docker-machine ssh $MASTER_MACHINE_NAME sudo docker swarm join-token worker -q)

WORKER_OPTIONS="$DRIVER_OPTIONS \
--amazonec2-request-spot-instance \
--amazonec2-spot-price=$SPOT_PRICE \
--amazonec2-instance-type=$WORKER_TYPE"
WORKER_MACHINE_NAME=${CLUSTER_PREFIX}-worker-

for INDEX in $(seq $NUM_WORKERS)
do
    (
        docker-machine create $WORKER_OPTIONS $WORKER_MACHINE_NAME$INDEX
        docker-machine ssh $WORKER_MACHINE_NAME$INDEX sudo docker swarm join --token $TOKEN $MASTER_IP:2377
    ) &
done
wait

eval $(docker-machine env $MASTER_MACHINE_NAME)

docker network create --driver overlay spark-network

docker service create \
--name master \
--constraint engine.labels.role==master \
--replicas 1 \
--network spark-network \
${SPARK_IMAGE} \
bin/spark-class org.apache.spark.deploy.master.Master

docker service create \
--name worker \
--constraint engine.labels.role!=master \
--replicas $NUM_WORKERS \
--network spark-network \
${SPARK_IMAGE} \
bin/spark-class org.apache.spark.deploy.worker.Worker spark://master:7077

docker service create \
--name proxy \
--constraint engine.labels.role==master \
--replicas 1 \
--publish "80:80" \
--publish "8081:8081" \
--network spark-network \
library/nginx:stable
