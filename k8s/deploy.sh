#!/bin/bash
set -e
./build-docker-image.sh
kapp deploy -y -a hello-ssl-certs -f ssl-certs.yml
kapp deploy -y -a hello-ssl -f deployment.yml