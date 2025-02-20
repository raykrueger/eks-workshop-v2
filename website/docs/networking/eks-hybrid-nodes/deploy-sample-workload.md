---
title: "Deploy Sample Workload"
sidebar_position: 20
sidebar_custom_props: { "module": false }
---

Now that we have our EKS Hybrid Node instance connected to the cluster, we can
deploy a sample workload. The workload we are going to deploy will be used to
simulate a "cloud bursting" use case. Below is a Kubernetes manifest that uses
`nodeAffinity` rules to tell the Kubernetes scheduler to *prefer* cluster nodes
with the `eks.amazonaws.com/compute-type=hybrid` label and value.

The `preferredDuringSchedulingIgnoredDuringExecution` strategy tells Kubernetes
to *prefer* our Hybrid Node when scheduling but *ignore* that during execution.
What that means is that when there is no more room on our single hybrid node,
these pods are free to schedule elsewhere in the cluster. Which is great! That
gives us our cloud bursting we wanted. However, the *IgnoredDuringExecution*
part means that when we scale back down, Kubernetes will randomly remove pods
and not worry about where they are running, because that is *ignored during
execution*.

Let's deploy our workload and come back to that problem.

```bash
$ kubectl apply -f ~/environment/eks-workshop/modules/networking/eks-hybrid-nodes/deployment.yaml
```

::yaml{file="manifests/modules/networking/eks-hybrid-nodes/deployment.yaml"}

After that deployment rolls out we should see three nginx-deployment pods, all deployed to our hybrid node.

```bash
$ kubectl get pods -o wide
NAME                                READY   STATUS    RESTARTS   AGE     IP            NODE                   NOMINATED NODE   READINESS GATES
nginx-deployment-7d7f668b68-4gjwh   1/1     Running   0          4m43s   10.53.0.53    mi-0c1ecca718b7fc1ca   <none>           <none>
nginx-deployment-7d7f668b68-74jz5   1/1     Running   0          4m43s   10.53.0.99    mi-0c1ecca718b7fc1ca   <none>           <none>
nginx-deployment-7d7f668b68-w652x   1/1     Running   0          4m43s   10.53.0.100   mi-0c1ecca718b7fc1ca   <none>           <none>
```

Install decheduler
```bash
$ kubectl apply -k ~/environment/eks-workshop/modules/networking/eks-hybrid-nodes/descheduler/
```
Scale up and burst into cloud
```bash
$ kubectl scale deployment nginx-deployment --replicas 12
```

Scale back down, after 1 minute pods will end up on our hybrid node
```bash
$ kubectl scale deployment nginx-deployment --replicas 3
```
