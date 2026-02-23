# Hands-on Kubernetes-02 : Kubernetes Basic Operations

The purpose of this hands-on training is to give students the knowledge of basic operations in a Kubernetes cluster.

## Learning Outcomes

At the end of this hands-on training, students will be able to;

- Learn basic operations of nodes, pods, deployments, and replicasets in Kubernetes

- Learn how to update and rollback deployments in Kubernetes

- Learn uses of namespace in Kubernetes

## Outline

- Part 1 - Setting up the Kubernetes Cluster

- Part 2 - Basic Operations in Kubernetes

- Part 3 - Namespaces in Kubernetes

- Part 4 - Deployment Rolling Update and Rollback in Kubernetes


## Part 1 - Setting up the Kubernetes Cluster

- Launch a Kubernetes Cluster of Ubuntu 22.04 with two nodes (one master, one worker) using the [Cloudformation Template to Create Kubernetes Cluster](./cfn-template-to-create-k8s-cluster.yml). *Note: Once the master node is up and running, the worker node automatically joins the cluster.*

>*Note: If you have a problem with the Kubernetes cluster, you can use this link for the lesson.*
>https://killercoda.com/playgrounds

- Check if Kubernetes is running and nodes are ready.

```bash
kubectl cluster-info
kubectl get node
```

## Part 2 - Basic Operations in Kubernetes

- Show the names and short names of the supported API resources as shown in the example:

|NAME|SHORTNAMES|
|----|----------|
|deployments|deploy
|events     |ev
|endpoints  |ep
|nodes      |no
|pods       |po
|services   |svc

```bash
kubectl api-resources
```

- To view kubectl commands:

```
kubectl help
```

- Get the documentation of `Nodes` and its fields.

```bash
kubectl explain nodes
```

- View the nodes in the cluster.

```bash
kubectl get nodes
```

### pods

- Get the documentation of `Pods` and its fields.

```bash
kubectl explain pods
```
  
- Create a YAML file named `mypod.yaml` and explain its fields.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: mynginx
    image: nginx
    ports:
    - containerPort: 80
```

- Create a pod with `kubectl create` command.

```bash
kubectl create -f mypod.yaml
```

- List the pods.

```bash
kubectl get pods
```

- List pods in `ps output format` with more information (such as node name).
  
```bash
kubectl get pods -o wide
```

- Show details of the pod.

```bash
kubectl describe pods/nginx-pod
```

- Show details of pod in `yaml format`.
  
```bash
kubectl get pods/nginx-pod -o yaml
```

- Delete the pod.

```bash
kubectl delete -f mypod.yaml
# or
kubectl delete pod nginx-pod
```

### ReplicaSets

- Get the documentation of `replicasets` and its fields.

```bash
kubectl explain replicaset
```

- Create a YAML file named `myreplicaset.yaml` and explain its fields.

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
  labels:
    environment: dev
spec:
  # modify replicas according to your case
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: mynginx
        image: nginx
        ports:
        - containerPort: 80
```

- Create the replicaset with `kubectl apply` command.

```bash
kubectl apply -f myreplicaset.yaml
```

- List the replicasets.

```bash
kubectl get replicaset
```

- List pods with more information.
  
```bash
kubectl get pods -o wide
```

- Show details of replicasets.

```bash
kubectl describe replicaset nginx-rs
```

- Delete replicasets (Note: When you delete a ReplicaSet, all the Pods it manages are also deleted).

```bash
kubectl delete replicaset nginx-rs
```

#### Pod Selector

The .spec.selector field is a label selector. 

The .spec.selector field and .spec.template.metadata field must be the same. There are additional issues related to this subject, such as loose coupling, but we discuss them in the service object.  

### Deployments

- Get the documentation of `Deployments` and its fields.

```bash
kubectl explain deployments
```

- Create a YAML file named `mydeployment.yaml` and explain its fields.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    environment: dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx  
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```

- Create the deployment with `kubectl apply` command.
  
```bash
kubectl apply -f mydeployment.yaml
```

- List the deployments.

```bash
kubectl get deployments
```

- List pods with more information.
  
```bash
kubectl get pods -o wide
```

- Show details of deployments.

```bash
kubectl describe deploy/nginx-deployment
```

- Print the logs for a container in a pod.

```bash
kubectl logs <pod-name>
```

- If there is a multi-container pod, we can print the logs of one container.

```bash
kubectl logs <pod-name> -c <container-name>
```

- Execute a command in a container.

```bash
kubectl exec <pod-name> -- date
```

```bash
kubectl exec <pod-name> -- cat /usr/share/nginx/html/index.html
```

- Open a bash shell in a container.

```bash
kubectl exec -it <pod-name> -- bash
```

- List the ReplicaSets.

```bash
kubectl get rs
```

- Show details of ReplicaSets.

```bash
kubectl describe rs <rs-name>
```

- Scale the deployment up to five replicas.

```bash
kubectl scale deploy nginx-deployment --replicas=5
```

- But each time, do we have to apply these commands for scaling? No, because there will be our YAML file and we can change it when we need scale.

>> Show when you apply mydeployment.yaml change, how does it differ?

- Delete a pod and show new pod is immediately created.

```bash
kubectl delete pod <pod-name>
kubectl get pods
```

- Delete deployments

```bash
kubectl delete deploy nginx-deployment
```

## Part 3 - Namespaces in Kubernetes

- List the current namespaces in a cluster and explain them. *Kubernetes supports multiple virtual clusters backed by the same physical cluster. These virtual clusters are called `namespaces`.*

```bash
kubectl get namespace
NAME              STATUS   AGE
default           Active   118m
kube-node-lease   Active   118m
kube-public       Active   118m
kube-system       Active   118m
```

>### default
>Kubernetes includes this namespace so that you can start using your new cluster without first creating a namespace.

>### kube-system
>The namespace for objects created by the Kubernetes system.

>### kube-public
>This namespace is readable by all clients (including those not authenticated). This namespace is mostly reserved for cluster usage, in case that some resources should be visible and readable publicly throughout the whole cluster. The public aspect of this namespace is only a convention, not a requirement.

>### kube-node-lease
>This namespace holds Lease objects associated with each node. Node leases allow the kubelet to send heartbeats so that the control plane can detect node failure.

- Create a new YAML file called `my-namespace.yaml` with the following content.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mynamespace
```

- Create a namespace using the `my-namespace.yaml` file.

```bash
kubectl apply -f ./my-namespace.yaml
```

- Alternatively, you can create a namespace using the following imperative command (useful for quick testing):

```bash
kubectl create namespace <namespace-name>
```

- Create pods in each namespace.

```bash
kubectl create deployment mynginx --image=nginx
kubectl create deployment myapache --image=httpd -n=mynamespace
```

- List the deployments in the `default` namespace.

```bash
kubectl get deployment
```

- List the deployments in `mynamespace`.

```bash
kubectl get deployment -n mynamespace
```

- List all deployments.

```bash
kubectl get deployment -o wide --all-namespaces
```

- Delete the namespace (Note: This will also delete all resources within that namespace).

```bash
kubectl delete namespaces mynamespace
```
- You can also create the Namespace and the Deployment together in a single YAML file.

- Create a YAML file named `namespace-and-deployment.yaml` with the following content.

```YAML
apiVersion: v1
kind: Namespace
metadata:
  name: mynamespace
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: mynamespace
  labels:
    environment: dev
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
```

- Apply the manifest.

```bash
kubectl apply -f namespace-and-deployment.yaml
```

- Verify the namespace and resources.

```bash
kubectl get ns
kubectl get deploy -n mynamespace
kubectl get rs -n mynamespace
kubectl get pods -n mynamespace -o wide
kubectl get deploy,rs,pod -n mynamespace -o wide
# optional (shows everything in the namespace)
kubectl get all -n mynamespace
```

- Delete (cleanup) the resources created with this manifest.

```bash
kubectl delete -f namespace-and-deployment.yaml
# or delete manually
kubectl delete deploy nginx-deployment -n mynamespace
kubectl delete ns mynamespace
```

## Part 4 - Deployment Rolling Update and Rollback in Kubernetes

- Create a new folder, name it deployment-lesson.

```bash
mkdir deployment-lesson
cd deployment-lesson
```

- Create a `mydeploy.yaml` and input text below. Pay attention that the image version is 1.0.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mydeploy
  labels:
    app: myapp
  annotations:
    kubernetes.io/change-cause: deploy/mydeploy is set as mycontainer=ondiacademy/ondiaweb:1.0
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  minReadySeconds: 10  # Wait 10 seconds before considering pod ready (helps prevent bad rollouts)
  strategy:
    type: RollingUpdate  # Update pods gradually, not all at once
    rollingUpdate:
      maxUnavailable: 1  # Maximum number of pods that can be unavailable during update
      maxSurge: 1        # Maximum number of pods that can be created above desired replicas
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: mycontainer
        image: ondiacademy/ondiaweb:1.0
        ports:
        - containerPort: 80
```

- Create the deployment with `kubectl apply` command.

```bash
kubectl apply -f mydeploy.yaml
```

- List the `Deployment`, `ReplicaSet`, and `Pods` of `mydeploy` deployment using a label and note the name of the ReplicaSet.

```bash
kubectl get deploy,rs,po -l app=myapp
```

- Describe the deployment and note the image of the deployment. In our case, it is `ondiacademy/ondiaweb:1.0`.

```bash
kubectl describe deploy mydeploy
```

- View previous rollout revisions.

```bash
kubectl rollout history deploy mydeploy
```

- Display details with revision number, in our case, 1. And note the name of the image.

```bash
kubectl rollout history deploy mydeploy --revision=1
```

- Upgrade image to version 2.0.

```bash
kubectl set image deploy mydeploy mycontainer=ondiacademy/ondiaweb:2.0
kubectl annotate deploy mydeploy kubernetes.io/change-cause="deploy/mydeploy is set as mycontainer=ondiacademy/ondiaweb:2.0"
```

- Monitor the rollout status (optional but useful).

```bash
kubectl rollout status deploy mydeploy
```

- Show the rollout history.

```bash
kubectl rollout history deploy mydeploy
```

- Display details about the revisions.

```bash
kubectl rollout history deploy mydeploy --revision=1
kubectl rollout history deploy mydeploy --revision=2
```

- List the `Deployment`, `ReplicaSet`, and `Pods` of `mydeploy` deployment using a label and explain ReplicaSets.

```bash
kubectl get deploy,rs,po -l app=myapp
```

- Upgrade image to version 3.0 with kubectl edit commands.

```bash
kubectl edit deploy/mydeploy
```

- We will see an output like below.

```yaml
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "2"
    kubectl.kubernetes.io/last-applied-configuration: |
    ...
```

- Change the `metadata.annotations.kubernetes.io/change-cause` and `spec.template.spec.containers.image` fields as below.

```yaml
...
...
    kubernetes.io/change-cause: kubectl set image deploy mydeploy mycontainer=ondiacademy/ondiaweb:3.0
...
...
    spec:
      containers:
      - image: ondiacademy/ondiaweb:3.0
...
...
```

- Show the rollout history.

```bash
kubectl rollout history deploy mydeploy
```

- Display details about the revisions.

```bash
kubectl rollout history deploy mydeploy --revision=1
kubectl rollout history deploy mydeploy --revision=2
kubectl rollout history deploy mydeploy --revision=3
```

- Apply `kubectl get rs` and show how many replica sets exist and explain why (Kubernetes keeps old ReplicaSets for rollback purposes).

```bash
kubectl get rs
```

- List the `Deployment`, `ReplicaSet`, and `Pods` of `mydeploy` deployment using a label and explain ReplicaSets.

```bash
kubectl get deploy,rs,po -l app=myapp
```

- Rollback to `revision 1`.

```bash
kubectl rollout undo deploy mydeploy --to-revision=1
```

- Show the rollout history and show that we have revisions 2, 3, and 4. Explain that the original revision, which is `revision 1`, becomes `revision 4`.

```bash
kubectl rollout history deploy mydeploy
kubectl rollout history deploy mydeploy --revision=2
kubectl rollout history deploy mydeploy --revision=3
kubectl rollout history deploy mydeploy --revision=4
```

- Try to pull up the `revision 1`, which is no longer available.

```bash
kubectl rollout history deploy mydeploy --revision=1
```

- List the `Deployment`, `ReplicaSet`, and `Pods` of `mydeploy` deployment using a label, and explain that the original ReplicaSet has been scaled up back to **two** (as defined in our deployment spec), and the newer ReplicaSets have been scaled down to zero.

```bash
kubectl get deploy,rs,po -l app=myapp
```

- Delete the deployment.

```bash
kubectl delete deploy -l app=myapp
```

## Additional Notes

### Rolling Update Strategy Parameters Explained

- **minReadySeconds**: The minimum time a pod should be ready before it's considered available. This helps prevent bad deployments from rolling out too quickly.

- **maxUnavailable**: Maximum number of pods that can be unavailable during the update process. Setting this to 1 means at least 1 pod will always be running.

- **maxSurge**: Maximum number of pods that can be created above the desired replica count during updates. Setting this to 1 allows Kubernetes to temporarily have 3 pods (2 desired + 1 surge) during the rollout.

### Why Multiple ReplicaSets Exist

Kubernetes keeps old ReplicaSets (scaled to 0) to enable quick rollbacks. When you rollback, it simply scales up the old ReplicaSet instead of pulling images again. This is more efficient than recreating everything from scratch.