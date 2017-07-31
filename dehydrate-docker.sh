#!/usr/bin/env bash

export CONTAINER_ID=${1}
export S3_BUCKET=${2}

CONTAINER_DETAILS=$(docker inspect ${CONTAINER_ID})
IMAGE_ID=$(echo ${CONTAINER_DETAILS} | jq -r '.[0].Config.Image')
IMAGE_DIGEST=$(echo ${CONTAINER_DETAILS} | jq -r '.[0].Image')
echo ${IMAGE_ID}@${IMAGE_DIGEST}

aws sts get-session-token | docker exec -i ${CONTAINER_ID} /opt/omero/cloudarchive/dehydrate.py ${S3_BUCKET} ${IMAGE_ID}@${IMAGE_DIGEST} -
