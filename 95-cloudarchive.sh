#!/usr/bin/env bash

set -eu

S3_BUCKET=${S3_BUCKET:-}
if [ ! -z "$S3_BUCKET" ]; then
    # Restore files essential to intiially start the server
    # TODO Call hydrate command
    echo "Restoring Thumbnails"
    gosu omero aws --no-sign-request s3 sync $S3_BUCKET/Thumbnails /OMERO/Thumbnails
    echo "Restoring FullText index"
    gosu omero aws --no-sign-request s3 sync $S3_BUCKET/FullText /OMERO/FullText

    # TODO Background download
    echo "Restoring Files"
    gosu omero aws --no-sign-request s3 sync $S3_BUCKET/Files /OMERO/Files
    echo "Restoring ManagedRepository"
    gosu omero aws --no-sign-request s3 sync $S3_BUCKET/ManagedRepository /OMERO/ManagedRepository
fi
