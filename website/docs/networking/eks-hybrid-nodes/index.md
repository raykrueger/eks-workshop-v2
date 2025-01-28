---
title: "Amazon EKS Hybrid Nodes"
sidebar_position: 50
weight: 20
sidebar_custom_props: { "module": true }
---

::required-time

:::caution Preview

This module is currently in preview, please [report any issues](https://github.com/aws-samples/eks-workshop-v2/issues) encountered.

:::

:::tip Before you start
Prepare your environment for this section:

```bash timeout=300 wait=30
$ prepare-environment networking/hybrid-nodes
```

This will make the following changes to your lab environment:

- Create a VPC with EC2 instances that will be used as Hybrid Nodes
- Create a Transit Gateway to facilitate communication between VPCs

:::

TODO: Architecture diagram of VPCs and TGW

Cluster was created using `10.42.0.0/16` as the CIDR.

We will use `10.50.0.0/16` for our _remote_ VPC CIDR.
