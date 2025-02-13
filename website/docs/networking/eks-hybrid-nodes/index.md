---
title: "Amazon EKS Hybrid Nodes"
sidebar_position: 50
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

:::

With Amazon EKS Hybrid Nodes, you can use your on-premises and edge infrastructure as nodes in Amazon EKS clusters. AWS manages the AWS-hosted Kubernetes control plane of the Amazon EKS cluster, and you manage the hybrid nodes that run in your on-premises or edge environments. This unifies Kubernetes management across your environments and offloads Kubernetes control plane management to AWS for your on-premises and edge applications.

With Amazon EKS Hybrid Nodes, there are no upfront commitments or minimum fees, and you are charged per hour for the vCPU resources of your hybrid nodes when they are attached to your Amazon EKS clusters. For more pricing information, see [Amazon EKS Pricing](https://aws.amazon.com/eks/pricing/).

TODO: Architecture Diagram
