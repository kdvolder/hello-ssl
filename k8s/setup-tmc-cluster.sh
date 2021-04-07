#!/bin/sh

#
# This script helps to prepare tmc k8s cluster to deploy this hello-world-ssl app
#

kapp deploy -a cert-mgr -f https://github.com/jetstack/cert-manager/releases/download/v1.2.0/cert-manager.yaml
kubectl get pods --namespace cert-manager