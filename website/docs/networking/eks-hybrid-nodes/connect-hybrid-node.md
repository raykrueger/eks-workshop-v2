---
title: "Connect Hybrid Node"
sidebar_position: 10
sidebar_custom_props: { "module": false }
---

Amazon EKS Hybrid Nodes use temporary IAM credentials provisioned by AWS SSM hybrid activations or AWS IAM Roles Anywhere to authenticate with the Amazon EKS cluster. In this workshop, we will use SSM hybrid activations. Run the following command to create a new activation and store the Activation Code and ID in `ssm-activation.json`.

```bash
$ aws ssm create-activation \
--default-instance-name hybrid-ssm-node \
--iam-role $HYBRID_ROLE_NAME \
--registration-limit 1 \
--region $AWS_REGION > ssm-activation.json
```

With our activation created, we can now create a `nodeconfig.yaml` which will be reference when we join our instance to the cluster. This utilizes the SSM Activation created in the previous step as well as the cluster name and region.

```bash
$ cat <<EOF > nodeconfig.yaml
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: $EKS_CLUSTER_NAME
    region: $AWS_REGION
  hybrid:
    ssm:
      activationCode: $(jq -r .ActivationCode ssm-activation.json)
      activationId: $(jq -r .ActivationId ssm-activation.json)
EOF
```

Let's copy that nodeconfig.yaml file over to our hybrid node instance.

```bash
$ mkdir -p ~/.ssh/
$ ssh-keyscan -H $HYBRID_NODE_IP &> ~/.ssh/known_hosts
$ scp -i private-key.pem nodeconfig.yaml ubuntu@$HYBRID_NODE_IP:/home/ubuntu/nodeconfig.yaml
```

Next, let's install the hybrid nodes dependencies using `nodeadm` on our EC2 instance. The hybrid nodes dependencies include containerd, kubelet, kubectl, and AWS SSM or AWS IAM Roles Anywhere components. See Hybrid nodes [nodeadm reference](https://docs.aws.amazon.com/eks/latest/userguide/hybrid-nodes-nodeadm.html) for more information on the components and file locations installed by nodeadm install.

```bash
$ ssh -i private-key.pem ubuntu@$HYBRID_NODE_IP "sudo nodeadm install $EKS_CLUSTER_VERSION --credential-provider ssm"
```

With our dependencies installed, and our `nodeconfig.yaml` in place, we initialize the instance as a hybrid node.

```bash
$ ssh -i private-key.pem ubuntu@$HYBRID_NODE_IP "sudo nodeadm init -c file://nodeconfig.yaml"
```

Lets see if our hybrid node has joined the cluster successfully.

```bash
$ kubectl get nodes
NAME                                          STATUS     ROLES    AGE    VERSION
ip-10-42-118-191.us-west-2.compute.internal   Ready      <none>   1h   v1.31.3-eks-59bf375
ip-10-42-154-9.us-west-2.compute.internal     Ready      <none>   1h   v1.31.3-eks-59bf375
ip-10-42-163-120.us-west-2.compute.internal   Ready      <none>   1h   v1.31.3-eks-59bf375
mi-015a9aae5526e2192                          NotReady   <none>   5m     v1.31.4-eks-aeac579
```

Great! The node appears but with a `NotReady` status. This is because we must install a CNI for hybrid nodes to become ready to serve workloads. So, let us first add the Cilium Helm repo.

```bash
$ helm repo add cilium https://helm.cilium.io/
```

With the repo added, we can install Cilium using the configuration provided below.

```bash
$ helm install cilium cilium/cilium \
--version 1.17.0 \
--namespace kube-system \
--values ~/environment/eks-workshop/modules/networking/eks-hybrid-nodes/cilium-values.yaml
```

::yaml{file="manifests/modules/networking/eks-hybrid-nodes/cilium-values.yaml"}

After installing Cilium our Hybrid Node should up, happy and healthy.

```bash
$ kubectl get nodes
NAME                                          STATUS     ROLES    AGE    VERSION
ip-10-42-118-191.us-west-2.compute.internal   Ready      <none>   1h   v1.31.3-eks-59bf375
ip-10-42-154-9.us-west-2.compute.internal     Ready      <none>   1h   v1.31.3-eks-59bf375
ip-10-42-163-120.us-west-2.compute.internal   Ready      <none>   1h   v1.31.3-eks-59bf375
mi-015a9aae5526e2192                          Ready      <none>   5m   v1.31.4-eks-aeac579
```

That's it! You now have a hybrid node up and running in your cluster.
