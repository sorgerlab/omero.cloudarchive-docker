#!/usr/bin/env bash
# Restore files essential to intially start the server and then in the
# background, sync remaining files
# TODO Call hydrate commands?

set -eu

S3_BUCKET=${S3_BUCKET:-}

function syncInitialFromS3 {
  echo "Restoring Thumbnails"
  aws --no-sign-request s3 sync $S3_BUCKET/Thumbnails /OMERO/Thumbnails
  echo "Restoring FullText index"
  aws --no-sign-request s3 sync $S3_BUCKET/FullText /OMERO/FullText
}

function syncRemainingFromS3 {
  echo "Restoring Files"
  aws --no-sign-request s3 sync $S3_BUCKET/Files /OMERO/Files
  echo "Restoring ManagedRepository"
  aws --no-sign-request s3 sync $S3_BUCKET/ManagedRepository /OMERO/ManagedRepository
}

if [ ! -z "$S3_BUCKET" ]; then
  syncInitialFromS3
  syncRemainingFromS3 &
fi
