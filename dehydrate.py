#!/usr/bin/env python

import os
import sys
from argparse import ArgumentParser, FileType
import json
from subprocess import Popen
import datetime


class DehydrateException(Exception):
    pass


def parse_credentials(f):
    data = json.load(f)

    try:
        creds = {
            'secret_access_key': data['Credentials']['SecretAccessKey'],
            'access_key_id': data['Credentials']['AccessKeyId'],
            'session_token': data['Credentials']['SessionToken']
        }

        if (
            creds['secret_access_key'] == ''
            or creds['access_key_id'] == ''
            or creds['session_token'] == ''
        ):
            raise DehydrateException('Value missing in supplied credentials')

        return creds

    except KeyError as e:
        raise DehydrateException('Key missing in supplied credentials', e)


parser = ArgumentParser(description='Dehydrate an OMERO instance into AWS S3')
parser.add_argument('s3_bucket', type=str,
                    help='S3 bucket to upload to, e.g. s3://mybucket')
parser.add_argument('image_digest', type=str,
                    help='ID and digest of docker image')
parser.add_argument('credentials', nargs='?', type=FileType('r'),
                    default=sys.stdin,
                    help='File containing AWS credentials')

args = parser.parse_args()
print(args)
# if sys.stdin.isatty():
#     raise DehydrateException('No credentials supplied')

creds = parse_credentials(args.credentials)
print(creds)
db_host = os.getenv('CONFIG_omero_db_host') or 'db'
db_user = os.getenv('CONFIG_omero_db_user') or 'omero'
db_name = os.getenv('CONFIG_omero_db_name') or 'omero'
db_pass = os.getenv('CONFIG_omero_db_pass') or 'omero'

# TODO Ensure the server is not running?

print('Dumping database to a file!')
os.environ['PGPASSWORD'] = db_pass
p = Popen(['pg_dump', '-h', db_host, '-U', db_user, '-w', '-d', db_name,
           '-Fp', '-f', '/OMERO/db.sql'],
          stdout=sys.stdout,
          stdin=sys.stderr)
exit_code = p.wait()
if exit_code != 0:
    raise DehydrateException('Failed to dump database')
print('Dumping database complete!')

print('Creating manifest!')
manifest = {
    'docker_image': args.image_digest,
    'utc_timestamp': datetime.datetime.utcnow().isoformat()
}
with open('/OMERO/manifest.json', 'w') as f:
    json.dump(manifest, f)
print('Manifest created!')

# TODO Formulate a list of files to dehydrate
#  - Default to everything in /OMERO
#  - /OMERO/omero_db.pg_dump (Database dump)
#  - /OMERO/ManagedRepository (Original image data)
#  - /OMERO/Files (Attachments, Pyramids, etc)
#  - /OMERO/Thumbnails (Thumbnails)
print('Syncing files to S3!')
os.environ['AWS_SECRET_ACCESS_KEY'] = creds['secret_access_key']
os.environ['AWS_ACCESS_KEY_ID'] = creds['access_key_id']
os.environ['AWS_SESSION_TOKEN'] = creds['session_token']
p = Popen(['aws', 's3', 'sync', '--exclude', '".omero/*"',
           '--exclude', '"BioFormatsCache/*"', '--exclude',
           '"DropBox/*"', '/OMERO', args.s3_bucket],
          stdout=sys.stdout,
          stdin=sys.stderr)
exit_code = p.wait()
if exit_code != 0:
    raise DehydrateException('Failed to sync data to S3')
print('Syncing of files to S3 complete!')
