#!/bin/sh

$app_name = $1

curl -O /app-config/$app_name.config repository.service/config/$app_name/$app_name.config
awk '{print "export " $0}' $app_name.config
source $app_name.config

mkdir /app
curl -O /app-files/$app_name.tgz repository.service/files/$app_name/$app_name.tgz

tar -C /app -xzvf /app-files/$app_name.tgz
cd /app
$(STARTUP_COMMAND)
