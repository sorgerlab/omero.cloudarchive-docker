#!/bin/bash

set -e

echo "Running /startup-root/ scripts as 'root' user"
for f in /startup-root/*; do
    if [ -f "$f" -a -x "$f" ]; then
        echo "Running $f $@"
        "$f" "$@"
    fi
done

echo "Running /startup/ scripts as 'omero' user"
HOME=/opt/omero/server gosu omero-server entrypoint.sh "$@"
