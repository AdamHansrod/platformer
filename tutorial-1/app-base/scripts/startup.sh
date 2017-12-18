#!/bin/sh

set -x

app_name=$1
repository_service=$2

cd /opt/app

echo "Downloading app config: ${repository_service}/config/${app_name}/${app_name}.config"
curl ${repository_service}/config/${app_name}/${app_name}.config -o config/${app_name}.config
awk '{print "export " $0}' config/${app_name}.config
cat config/${app_name}.config
source config/${app_name}.config

echo "Downloading app package: ${repository_service}/files/${app_name}/${app_name}.tgz"
curl ${repository_service}/files/${app_name}/${app_name}.tgz -o source/${app_name}.tgz

tar -C /opt/app/files -xzvf source/${app_name}.tgz

echo "Running startup command: ${STARTUP_COMMAND}"
cd /opt/app/files

exec $STARTUP_COMMAND