#!/bin/bash
set -e
cd ..
./mvnw spring-boot:build-image -Dspring-boot.build-image.imageName=kdvolder/hello-world
docker push kdvolder/hello-world
