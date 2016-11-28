#!/bin/bash
docker run -ti -v ${PWD}/projects/:/projects --workdir /projects/ -p 8080-8099:8080-8099 -p 18001:18001 aspire bash
