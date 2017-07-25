AWS
---

Deploy a local setup using docker

```bash
# Quickstart
docker-compose up
```

To customize the configuration either edit `docker-compose.yml` or run the
docker container's manually like this:

```bash

docker run \
  -d \
  --name postgres \
  -e POSTGRES_PASSWORD=postgres \
  postgres:9.4

docker run \
  -d \
  --name omero-master \
  --link postgres:db \
  -e DBNAME=postgres \
  -e DBPASS=postgres \
  -e DBUSER=postgres \
  -e PUBLIC_GROUP=public-group \
  -e ROOTPASS=omero \
  -p 4063:4063 \
  -p 4064:4064 \
  dpwrussell/omero.cloudarchive

docker run \
  -d \
  --name omero-web \
  --link omero-master:master \
  -e PUBLIC_GROUP=public-group \
  -p 8080:8080 \
  dpwrussell/omero-grid-web
```

Note: It takes a few minutes for the containers to start and as they have to
start and stop services during configuration so it may appear to be working
then offline, then working again.

Now the OMERO infrastructure is up and running normal importing using Insight
can be commenced on localhost, standard OMERO ports (unless changed in the
above examples). The web client will also be operational on port 8080 (again,
unless changed in the above examples).

In-place
--------

It is also possible to do in-place importing. This is a good way of creating
an archive without losing the original file-structure of the data. This is
useful if the data archive is multipurpose, being accessed through OMERO, but
also directly, thus preserving the original filesystem structure can be
desirable.

When running the docker container for `omero-master`, include an additional
setting `-v <data_dir>:/mnt/<data_dir> `, adding a local directory to the
container.

```bash

docker run \
  -d \
  --name omero-master \
  --link postgres:db \
  -e DBNAME=postgres \
  -e DBPASS=postgres \
  -e DBUSER=postgres \
  -e PUBLIC_GROUP=public-group \
  -p 4063:4063 \
  -p 4064:4064 \
  -v /TestData:/mnt/TestData \
  dpwrussell/omero.cloudarchive
```

Then log into the omero container through docker:

```bash
docker exec -it --user omero omero-master /bin/bash
```

Once logged in, create a symlink from the mounted data directory to a directory
in `/OMERO`, like this:

```bash
ln -s /mnt/TestData/project1 /OMERO/inplace
```

Warning: When dehydrating this OMERO instance, everything in the symlinked
directory will be uploaded to S3. In the above example this would be everything
in the `/mnt/TestData/project1` via the `/OMERO/inplace` symlink. This is an
intentional effort to retain the files from the original structure which may
or may not be relevant to OMERO.

We can now do an in-place imports of anything in `/OMERO/inplace`, in this
example we will import everything:

```bash
~/OMERO.server/bin/omero import -- --transfer=ln_s /OMERO/inplace/
```

Dehydrate
---------

Once an archive is built, it can be "dehydrated" into S3. First, generate
some temporary credentials to use inside the omero-master container. Do this
on whatever machine you have configured to communicate with AWS.

```bash
aws sts get-session-token
```

Then login to omero-master through docker.

```bash
docker exec -it --user omero omero-master /bin/bash
```

Create a bucket in S3 to dehydrate the archive into. This can be done on the
AWS console or through the CLI like this (In this case I make it publicly
readable to anyone, and in the us-east-1 region):

```bash
export BUCKETNAME="<bucket_name>"
aws s3api create-bucket --bucket ${BUCKETNAME} --acl public-read --region us-east-1
echo "{ \"Version\" : \"2012-10-17\", \"Statement\" : [ { \"Effect\" : \"Allow\", \"Principal\" : \"*\", \"Resource\" : [ \"arn:aws:s3:::ionewfioewn9023/*\" ], \"Sid\" : \"PublicReadGetObject\", \"Action\" : [ \"s3:GetObject\" ] } ] }" > s3_public.json
aws s3api put-bucket-policy --bucket ${BUCKETNAME} --policy file://s3_public.json --region us-east-1
```

Stop the server and begin the dehydration using the `~/dehydrate.sh` script and the temporary
AWS credentials.

```bash
~/dehydrate.sh <aws_access_key_id> <aws_secret_access_key> <aws_session_token> <s3_bucket>
```

This may take some time depending on the size of the repository to upload.
