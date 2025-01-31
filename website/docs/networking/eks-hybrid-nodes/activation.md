---
title: "Create an Activation"
sidebar_position: 20
---

Amazon EKS Hybrid Nodes use temporary IAM credentials provisioned by AWS SSM hybrid activations or AWS IAM Roles Anywhere to authenticate with the Amazon EKS cluster. For this workshop, we will use AWS SSM hybrid activations with the Amazon EKS Hybrid Nodes CLI (nodeadm).

TODO: Need to make role used here first? Or check perms on the default role.

First, we will create a new activation with Systems Manager:

```bash
$ aws ssm create-activation \
    --default-instance-name hybrid-ssm-node \
    --iam-role AmazonEKSHybridNodesRole \
    --registration-limit 3 \
    --region us-east-1 \
    --tags "Key=Environment,Value=Workshop"
```

If the activation is created successfully, the system immediately returns an Activation Code and ID.
:::caution
Copy this information and store it in a safe place. If you navigate away from the console or close the command window, you might lose this information. If you lose it, you must create a new activation.
:::
