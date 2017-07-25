#!/usr/bin/env bash

export CONTAINER_ID=${1}

CONTAINER_DETAILS=$(docker inspect ${CONTAINER_ID})
IMAGE_ID=$(echo ${CONTAINER_DETAILS} | jq -r '.[0].Config.Image')
IMAGE_DIGEST=$(echo ${CONTAINER_DETAILS} | jq -r '.[0].Image')
echo ${IMAGE_ID}@${IMAGE_DIGEST}

docker exec -t ${CONTAINER_ID} /opt/omero/cloudarchive/dehydrate.sh
