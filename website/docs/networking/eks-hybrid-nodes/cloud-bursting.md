---
title: "Cloud Bursting Example"
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

Install [Descheeduler](https://github.com/kubernetes-sigs/descheduler).
Descheduler will be responsible for taking down any dangling pods left running
on our EC2 nodes when we scale back down.

```bash
$ kubectl apply -k ~/environment/eks-workshop/modules/networking/eks-hybrid-nodes/descheduler/
```

Scale up and burst into cloud. The nginx deployment here is requesting an
ureasonable amount of CPU (200m) for demonstration purposes. This means we can
fit about 8 instances on our hybrid node. When we scale up to 12 instances of
the pod, there is no room to schedule them. Given that we are using the
`preferredDuringSchedulingIgnoredDuringExecution` affinity policy, this means
that we start with our hybrid node. Anything that is unschedulable is allowed to
be scheduled elsewhere (our cloud instances).

```bash
$ kubectl scale deployment nginx-deployment --replicas 12
```

Now when we run `kubectl get pods` we see that our extras have been deployed onto the EC2 instances attached to our EKS cluster as a Managed Node Group.

```bash
$ kubectl get pods -o wide
NAME                                READY   STATUS    RESTARTS   AGE   IP              NODE                                          NOMINATED NODE   READINESS GATES
nginx-deployment-7d7f668b68-466rg   1/1     Running   0          7s    10.42.127.211   ip-10-42-119-239.us-west-2.compute.internal   <none>           <none>
nginx-deployment-7d7f668b68-dcgn4   1/1     Running   0          7s    10.42.187.246   ip-10-42-165-219.us-west-2.compute.internal   <none>           <none>
nginx-deployment-7d7f668b68-fkdb6   1/1     Running   0          7s    10.53.0.98      mi-0026d09f0152f3e60                          <none>           <none>
nginx-deployment-7d7f668b68-fzg75   1/1     Running   0          7s    10.53.0.102     mi-0026d09f0152f3e60                          <none>           <none>
nginx-deployment-7d7f668b68-gcsb8   1/1     Running   0          7s    10.53.0.82      mi-0026d09f0152f3e60                          <none>           <none>
nginx-deployment-7d7f668b68-lkv8z   1/1     Running   0          45s   10.53.0.27      mi-0026d09f0152f3e60                          <none>           <none>
nginx-deployment-7d7f668b68-pgfn9   1/1     Running   0          7s    10.53.0.81      mi-0026d09f0152f3e60                          <none>           <none>
nginx-deployment-7d7f668b68-rw2lg   1/1     Running   0          7s    10.42.187.240   ip-10-42-165-219.us-west-2.compute.internal   <none>           <none>
nginx-deployment-7d7f668b68-sxzxc   1/1     Running   0          45s   10.53.0.87      mi-0026d09f0152f3e60                          <none>           <none>
nginx-deployment-7d7f668b68-t7xsj   1/1     Running   0          45s   10.53.0.5       mi-0026d09f0152f3e60                          <none>           <none>
nginx-deployment-7d7f668b68-tv2lw   1/1     Running   0          7s    10.53.0.69      mi-0026d09f0152f3e60                          <none>           <none>
nginx-deployment-7d7f668b68-x62m2   1/1     Running   0          7s    10.42.155.144   ip-10-42-140-159.us-west-2.compute.internal   <none>           <none>
```

Now when we scale back down, some instances will be left on our Managed Node
Group. In a minute or less Descheduler will come around and clean that up. We'll
use the `--watch` argument to watch and wait for that to happen.

```bash
$ kubectl scale deployment nginx-deployment --replicas 3
$ kubectl get pods -o wide --watch
...
nginx-deployment-7d7f668b68-5jz2b   1/1     Running             0          2s    10.53.0.97      mi-0026d09f0152f3e60                          <none>           <none>
nginx-deployment-7d7f668b68-kslfq   1/1     Running             0          3s    10.53.0.110     mi-0026d09f0152f3e60                          <none>           <none>
nginx-deployment-7d7f668b68-qsqzx   1/1     Running             0          3s    10.53.0.111     mi-0026d09f0152f3e60                          <none>           <none>
```
