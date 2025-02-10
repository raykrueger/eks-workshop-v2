#!/bin/bash

set -e

logmessage "Cleaning up EKS Hybrid Nodes Module"

kubectl delete deployment nginx-deployment || true

helm uninstall cilium --ignore-not-found || true

helm repo remove cilium || true

kubectl delete nodes -l eks.amazonaws.com/compute-type=hybrid || true