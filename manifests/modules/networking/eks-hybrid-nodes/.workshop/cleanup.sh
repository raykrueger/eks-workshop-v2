#!/bin/bash

set -e

logmessage "Cleaning up EKS Hybrid Nodes Module"

kubectl delete namespace ui

kubectl delete namespace catalog

kubectl delete deployment nginx-deployment --ignore-not-found=true

uninstall-helm-chart kube-system cilium

kubectl delete nodes -l eks.amazonaws.com/compute-type=hybrid --ignore-not-found=true

kubectl delete -k ~/environment/eks-workshop/modules/networking/eks-hybrid-nodes/descheduler/ --ignore-not-found=true