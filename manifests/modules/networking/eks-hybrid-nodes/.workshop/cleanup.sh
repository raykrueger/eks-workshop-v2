#!/bin/bash

set -e

logmessage "Cleaning up EKS Hybrid Nodes Module"

kubectl delete deployment nginx-deployment || true

uninstall-helm-chart kube-system cilium

kubectl delete nodes -l eks.amazonaws.com/compute-type=hybrid || true
