#!/usr/bin/env bash

set -eu

AWS_ACCESS_KEY_ID=${1}
AWS_SECRET_ACCESS_KEY=${2}
AWS_SESSION_TOKEN=${3}
S3_BUCKET=${4}

# TODO Ensure the server is not running

DBHOST=${DBHOST:-}
if [ -z "$DBHOST" ]; then
    DBHOST=db
fi

# Dump the database to a file
PGPASSWORD=$DBPASS pg_dump -h $DBHOST -U $DBUSER -w -d $DBNAME -Fc -f /OMERO/omero_db.pg_dump

# TODO Formulate a list of files to dehydrate
#  - Default to everything in /OMERO
#  - /OMERO/omero_db.pg_dump (Database dump)
#  - /OMERO/ManagedRepository (Original image data)
#  - /OMERO/Files (Attachments, Pyramids, etc)
#  - /OMERO/Thumbnails (Thumbnails)

# Sync the files to S3
AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN \
aws s3 sync --exclude ".omero/*" --exclude "BioFormatsCache/*" --exclude "DropBox/*" /OMERO $S3_BUCKET
