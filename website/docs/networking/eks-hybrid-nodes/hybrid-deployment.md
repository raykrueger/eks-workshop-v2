---
title: "Deploy workload to Hybrid Node"
sidebar_position: 10
sidebar_custom_props: { "module": false }
weight: 25 # used by test framework
---

Deploy the sample application - deployment, service, and ingress objects.

```bash
$ kubectl apply -k ~/environment/eks-workshop/modules/networking/eks-hybrid-nodes/kustomize
```


Check status of pods created - all 3 pods should have been scheduled on the remote node, with name starting with `mi-`. 

```bash
$ kubectl get pods -n nginx-remote -o=custom-columns='NAME:.metadata.name,NODE:.spec.nodeName'
```



check the status of the ingress, note the `Address` field of the ingress object:

```bash
$ kubectl get ingress -n nginx-remote 
```

The provisioning of the Application Load Balancer may take a couple minutes.  Check the status of the load balancer created for the ingress with command:

```bash
$ aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-nginxrem-nginx`) == `true`]'
```

Continue to next step if the state changes to 'Active'.

Copy the Address value of Ingress, or the DNSName of the Load Balancer information, paste it into browser address bar and view the page.  Or run

```bash
$ curl http://<Address>
```

The output on the web page or curl output should look like

```
Connected to 10.53.0.x on mi-xxxxxxxxxxx 
```

Where 10.53.0.x is the IP address of the pod receiving the request from load balancer, and mi-xxxxxxxxx is name of the remote pod.  Rerun the curl command a few times and note that the Pod IP changes in each request and the node name stays the same, as all pods are scheduled on the same remote node.
