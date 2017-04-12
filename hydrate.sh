#!/usr/bin/env bash

set -eu

AWS_ACCESS_KEY_ID=${1}
AWS_SECRET_ACCESS_KEY=${2}
AWS_SESSION_TOKEN=${3}
S3_BUCKET=${4}

# Sync the files from S3
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN \
aws s3 sync $S3_BUCKET /OMERO

# TODO Check that database does not already have a schema deployed

# Restore the database
PGPASSWORD=$DBPASS pg_restore -h $DB_PORT_5432_TCP_ADDR -U $DBUSER -w -d $DBNAME -Fc /OMERO/omero_db.pg_dump

# TODO Check that the version of the software deployed matches the version of
# the database
