#!/bin/bash

set -eu

# TODO Review defaults, especially passwords
TARGET=${1:-master}
export OMERO_USERDIR=/home/omero
OMERO_SERVER=$OMERO_USERDIR/OMERO.server
omero="gosu omero $OMERO_SERVER/bin/omero"
S3_BUCKET=${S3_BUCKET:-}
PUBLIC_GROUP=${PUBLIC_GROUP:-}

function volumePermissions {
    if [[ ! $(stat -c %U /OMERO) = omero ]]; then
        chown omero:omero -R /OMERO
    fi

    if [[ ! $(stat -c %U /home/omero/OMERO.server/var) = omero ]]; then
        chown omero:omero -R /home/omero/OMERO.server/var
    fi
}

function publicUser {
    # Configure public user if appropriate
    if [ ! -z "$PUBLIC_GROUP" ]; then
        PUBLIC_USER=${PUBLIC_USER:-public-user}
        PUBLIC_PASSWORD=${PUBLIC_PASSWORD:-omero}

        # The server must be running in order to do the group and user creation
        $omero admin start
        $omero -s localhost -p 4064 -u root -w $ROOTPASS group info $PUBLIC_GROUP \
            && echo "Skipping existing PUBLIC_GROUP ($PUBLIC_GROUP) creation" \
            || $omero -s localhost -p 4064 -u root -w $ROOTPASS group add --type read-only $PUBLIC_GROUP
        $omero -s localhost -p 4064 -u root -w $ROOTPASS user info $PUBLIC_USER \
            && echo "Skipping existing PUBLIC_USER ($PUBLIC_USER) creation" \
            || $omero -s localhost -p 4064 -u root -w $ROOTPASS user add --group-name $PUBLIC_GROUP -P $PUBLIC_PASSWORD $PUBLIC_USER Public User
        $omero admin stop
    fi
}

function sync {
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
}

if [ "$TARGET" = bash ]; then
    echo "Entering a shell"
    exec gosu omero bash -l
elif [ "$TARGET" = master ]; then

    # Ensure omero user owns the volumes it needs
    volumePermissions

    # Remaining args are the servers to run, default (no args) is to run all
    # on master
    if [ $# -gt 1 ]; then
        shift
        ARGS="$@"
    else
        ARGS=
    fi
    gosu omero sh -c "./process_defaultxml.py OMERO.server/etc/templates/grid/default.xml.orig \
        ${ARGS} > OMERO.server/etc/templates/grid/default.xml"

    DBHOST=${DBHOST:-}
    if [ -z "$DBHOST" ]; then
        DBHOST=db
    fi
    DBUSER=${DBUSER:-omero}
    DBNAME=${DBNAME:-omero}
    DBPASS=${DBPASS:-omero}
    ROOTPASS=${ROOTPASS:-omero}
    MASTER_IP=$(hostname -i)

    export PGPASSWORD="$DBPASS"

    i=0
    # TODO Could be done with `gosu omero`
    while ! psql -h $DBHOST -U$DBUSER $DBNAME >/dev/null 2>&1 < /dev/null; do
        i=$(($i+1))
        if [ $i -ge 50 ]; then
            echo "$(date) - postgres:5432 still not reachable, giving up"
            exit 1
        fi
        echo "$(date) - waiting for postgres:5432..."
        sleep 1
    done
    echo "postgres connection established"

    # TODO Could be done with `gosu omero`
    psql -w -h $DBHOST -U$DBUSER $DBNAME -c \
        "select * from dbpatch" 2> /dev/null && {
        # TODO Potentially upgrade would make sense, but this requires version
        # number comparison. Then upgrade/exit/continue appropriately
        echo "INFO: Database schema already initialized"
    } || {
        # Restore database if this is a hydrate
        if [ ! -z "$S3_BUCKET" ]; then

            # TODO Add option to access S3 with credentials
            gosu omero aws --no-sign-request s3 cp $S3_BUCKET/omero_db.pg_dump /OMERO/omero_db.pg_dump
            if [ ! -f /OMERO/omero_db.pg_dump ]; then
                echo "${S3_BUCKET}/omero_db.pg_dump not accessible"
                exit 1
            fi

            echo "Restoring database"
            # TODO Call hydrate command
            # TODO Could be done with `gosu omero`
            PGPASSWORD=$DBPASS pg_restore -h $DBHOST -U $DBUSER -w -d $DBNAME -Fc /OMERO/omero_db.pg_dump

        # Otherwise, initialise
        else
            echo "Initialising database"
            gosu omero omego db init --dbhost "$DBHOST" --dbuser "$DBUSER" --dbname "$DBNAME" \
                --dbpass "$DBPASS" --rootpass "$ROOTPASS" --serverdir=OMERO.server
        fi
    }

    $omero config set omero.db.host "$DBHOST"
    $omero config set omero.db.user "$DBUSER"
    $omero config set omero.db.name "$DBNAME"
    $omero config set omero.db.pass "$DBPASS"

    $omero config set omero.master.host "$MASTER_IP"

    if stat -t /config/* > /dev/null 2>&1; then
        for f in /config/*; do
            echo "Loading $f"
            $omero load "$f"
        done
    fi

    # Create publicUser if required and necessary
    publicUser

    # Sync data if appropriate
    sync

    echo "Starting $TARGET"
    exec $omero admin start --foreground
else
    # TODO Add gosu or remove entirely
    MASTER_ADDR=${MASTER_ADDR:-}
    if [ -z "$MASTER_ADDR" ]; then
        MASTER_ADDR=${MASTER_PORT_4061_TCP_ADDR:-}
    fi
    if [ -z "$MASTER_ADDR" ]; then
        echo "ERROR: Master address not found"
        exit 2
    fi
    SLAVE_ADDR=$(hostname -i)

    $omero config set omero.master.host "$MASTER_ADDR"

    if stat -t /config/* > /dev/null 2>&1; then
        for f in /config/*; do
            echo "Loading $f"
            $omero load "$f"
        done
    fi

    echo "Master addr: $MASTER_ADDR Slave addr: $SLAVE_ADDR"
    sed -e "s/@omero.slave.host@/$SLAVE_ADDR/" -e "s/@slave.name@/$TARGET/" \
        OMERO.server/etc/templates/slave.cfg > OMERO.server/etc/$TARGET.cfg
    grep '^Ice.Default.Router=' OMERO.server/etc/ice.config || \
        echo Ice.Default.Router= >> OMERO.server/etc/ice.config
    sed -i -r "s|^(Ice.Default.Router=).*|\1OMERO.Glacier2/router:tcp -p 4063 -h $MASTER_ADDR|" \
        OMERO.server/etc/ice.config

    echo "Starting node $TARGET"
    exec $omero node $TARGET start --foreground
fi
