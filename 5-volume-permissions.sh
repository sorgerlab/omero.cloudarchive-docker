#!/usr/bin/env bash
# Ensure omero user owns the volumes it needs

set -eu

if [[ ! $(stat -c %U /OMERO) = omero-server ]]; then
  echo "Making omero-server the owner of /OMERO"
  chown omero-server:omero-server -R /OMERO
fi

if [[ ! $(stat -c %U /opt/omero/server/OMERO.server/var) = omero-server ]]; then
  echo "Making omero-server the owner of /opt/omero/server/OMERO.server/var/"
  chown omero-server:omero-server -R /opt/omero/server/OMERO.server/var/
fi
