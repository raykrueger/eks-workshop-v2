---
title: "Create Credentials"
sidebar_position: 10
---

TODO: need to reference created IAM role or make instructions for making the role

Before you can connect hybrid nodes to your Amazon EKS cluster, you must create an IAM role that will be used with AWS SSM hybrid activations or AWS IAM Roles Anywhere for your hybrid nodes credentials. Later we will map the IAM role to Kubernetes Role-Based Access Control (RBAC).

In this workshop, we will download and apply a CloudFormation template to create the Hybrid Nodes IAM Role:

```bash
$ curl -OL 'https://raw.githubusercontent.com/aws/eks-hybrid/refs/heads/main/example/hybrid-ssm-cfn.yaml'
```

Create a `cfn-ssm-parameters.json` with the following options. The combination of the tag key and tag value is used in the condition for the `ssm:DeregisterManagedInstance` to only allow the Hybrid Nodes IAM role to deregister the AWS SSM managed instances that are associated with your AWS SSM hybrid activation.

```json
{
  "Parameters": {
    "RoleName": "AmazonEKSHybridNodesRole",
    "SSMDeregisterConditionTagKey": "Environment",
    "SSMDeregisterConditionTagValue": "Workshop"
  }
}
```

Deploy the CloudFormation stack:

```bash
$ aws cloudformation deploy \
    --stack-name hybrid-nodes-stack \
    --template-file hybrid-ssm-cfn.yaml \
    --parameter-overrides file://cfn-ssm-parameters.json \
    --capabilities CAPABILITY_NAMED_IAM
```
