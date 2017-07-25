#!/usr/bin/env bash

set -eu

export AWS_ACCESS_KEY_ID=${1}
export AWS_SECRET_ACCESS_KEY=${2}
export AWS_SESSION_TOKEN=${3}
export S3_BUCKET=${4}

# TODO Ensure the server is not running

CONFIG_omero_db_host=${CONFIG_omero_db_host:-}
if [ -n "$CONFIG_omero_db_host" ]; then
    DBHOST="$CONFIG_omero_db_host"
else
    DBHOST=db
fi
DBUSER="${CONFIG_omero_db_user:-omero}"
DBNAME="${CONFIG_omero_db_name:-omero}"
DBPASS="${CONFIG_omero_db_pass:-omero}"
ROOTPASS="${ROOTPASS:-omero}"

export PGPASSWORD="$DBPASS"

# Dump the database to a file
pg_dump -h $DBHOST -U $DBUSER -w -d $DBNAME -Fp -f /OMERO/omero_db.pg_dump

# TODO Formulate a list of files to dehydrate
#  - Default to everything in /OMERO
#  - /OMERO/omero_db.pg_dump (Database dump)
#  - /OMERO/ManagedRepository (Original image data)
#  - /OMERO/Files (Attachments, Pyramids, etc)
#  - /OMERO/Thumbnails (Thumbnails)

# Sync the files to S3
# AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
# AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
# AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN \
echo "Syncing files to S3"
aws s3 sync --exclude ".omero/*" --exclude "BioFormatsCache/*" --exclude "DropBox/*" /OMERO $S3_BUCKET
echo "Syncing of files to S3 Complete"
