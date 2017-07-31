#!/usr/bin/env bash

set -eu

S3_BUCKET=${S3_BUCKET:-}

# Restore database if this is a hydrate
if [ ! -z "$S3_BUCKET" ]; then
  # TODO Add option to access S3 with credentials
  echo "Downloading database schema from S3 bucket: ${S3_BUCKET}/db.sql"
  aws --no-sign-request s3 cp $S3_BUCKET/db.sql /opt/omero/sql/db.sql
  if [ ! -f /opt/omero/sql/db.sql ]; then
      echo "${S3_BUCKET}/db.sql not accessible"
      exit 1
  fi
fi
