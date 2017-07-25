#!/usr/bin/env bash

set -eu

S3_BUCKET=${S3_BUCKET:-}

# Restore database if this is a hydrate
if [ ! -z "$S3_BUCKET" ]; then
  # TODO Add option to access S3 with credentials
  aws --no-sign-request s3 cp $S3_BUCKET/omero_db.pg_dump /sql/db.sql
  if [ ! -f /sql/db.sql ]; then
      echo "${S3_BUCKET}/omero_db.pg_dump not accessible"
      exit 1
  fi
fi
