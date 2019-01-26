#!/bin/bash -ex

dockerhub_user=$1
dockerhub_password=$2
version=$3

docker login -u $dockerhub_user -p $dockerhub_password

docker images | awk '/bosh-event-resource/{ print $1":"$2 }' | xargs docker rmi
docker images | awk '/<none>/{ print $3 }' | xargs docker rmi

docker build . -t bosh-event-resource --squash
docker tag bosh-event-resource $dockerhub_user/bosh-event-resource:latest
docker tag bosh-event-resource $dockerhub_user/bosh-event-resource:$version

docker push $dockerhub_user/bosh-event-resource
