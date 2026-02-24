# Hands-on Kubernetes-03: Kubernetes Networking and Service Discovery

The purpose of this hands-on training is to give students the knowledge of Kubernetes Services.

## Learning Outcomes

At the end of this hands-on training, students will be able to:

- Explain the benefits of logically grouping `Pods` with `Services` to access an application.

- Explore the service discovery options available in Kubernetes.

- Learn different types of Services in Kubernetes.

- Understand how DNS resolution works in Kubernetes clusters.

## Outline

- Part 1 - Setting up the Kubernetes Cluster

- Part 2 - Services, Load Balancing, and Networking in Kubernetes

- Part 3 - Advanced Service Concepts and Troubleshooting

## Part 1 - Setting up the Kubernetes Cluster

- Launch a Kubernetes Cluster of Ubuntu 22.04 with two nodes (one master, one worker) using the [Cloudformation Template to Create Kubernetes Cluster](../S2-kubernetes-02-basic-operations/cfn-template-to-create-k8s-cluster.yml). 

> **Note:** Once the master node is up and running, the worker node automatically joins the cluster.

> **Alternative:** If you have a problem with the Kubernetes cluster, you can use this link for the lesson:
> https://killercoda.com/playgrounds

- Check if Kubernetes is running and nodes are ready.

```bash
kubectl cluster-info
kubectl get nodes
```

**Expected Output:**
```text
NAME           STATUS   ROLES           AGE   VERSION
kube-master    Ready    control-plane   10m   v1.28.0
kube-worker    Ready    <none>          5m    v1.28.0
```

## Part 2 - Services, Load Balancing, and Networking in Kubernetes

Kubernetes networking addresses four concerns:

- Containers within a Pod use networking to communicate via loopback.

- Cluster networking provides communication between different Pods.

- The Service resource lets you expose an application running in Pods to be reachable from outside your cluster.

- You can also use Services to publish services only for consumption inside your cluster.

### What is a Service?

An abstract way to expose an application running on a set of Pods as a network service.

With Kubernetes, you don't need to modify your application to use an unfamiliar service discovery mechanism.

Kubernetes gives Pods their IP addresses and a single DNS name for a set of Pods, and can load-balance across them.

### Motivation

Kubernetes Pods are mortal. They are born, and when they die, they are not resurrected. If you use a Deployment to run your app, it can create and destroy Pods dynamically.

Each Pod gets its own IP address, however in a Deployment, the set of Pods running in one moment in time could be different from the set of Pods running that application a moment later.

This leads to a problem: if some set of Pods (call them "backends") provides functionality to other Pods (call them "frontends") inside your cluster, how do the frontends find out and keep track of which IP address to connect to, so that the frontend can use the backend part of the workload?

**Answer: Services**

### Service Discovery

The basic building block starts with the Pod, which is just a resource that can be created and destroyed on demand. Because a Pod can be moved or rescheduled to another Node, any internal IPs that this Pod is assigned can change over time.

If we were to connect to this Pod to access our application, it would not work on the next re-deployment. To make a Pod reachable to external networks or clusters without relying on any internal IPs, we need another layer of abstraction. Kubernetes offers that abstraction with what we call a `Service`.

`Services` provide network connectivity to Pods that work uniformly across clusters. Kubernetes services provide discovery and load balancing. `Service Discovery` is the process of figuring out how to connect to a service.

**Key Points about Service Discovery:**

- Service Discovery is like networking your Containers.

- DNS in Kubernetes is a `Built-in Service` managed by `CoreDNS` (or `Kube-DNS` in older versions).

- DNS Service is used within Pods to find other services running on the same Cluster.

- Multiple containers running within the same Pod don't need DNS service, as they can contact each other.

- Containers within the same Pod can connect to other containers using `PORT` on `localhost`.

- To make DNS work, a Pod always needs a `Service Definition`.

- CoreDNS is a database containing key-value pairs for lookup.

- Keys are names of services, and values are IP addresses on which those services are running.

### Defining and Deploying Services

- Let's define a setup to observe the behavior of `services` in Kubernetes and how they work in practice.

- Create a folder and name it service-lessons.

```bash
mkdir service-lessons
cd service-lessons
```

- Create a `yaml` file named `web-flask.yaml` and explain its fields.

```yaml
apiVersion: apps/v1 
kind: Deployment 
metadata:
  name: web-flask-deploy
  labels:
    env: dev
spec:
  replicas: 3 
  selector:  
    matchLabels:
      app: web-flask
  template: 
    metadata:
      labels:
        app: web-flask
    spec:
      containers:
      - name: web-flask-pod
        image: ondiacademy/cw_web_flask1
        ports:
        - containerPort: 5000
```

**Field Explanations:**
- `replicas: 3` - Creates 3 identical Pods
- `selector.matchLabels` - Tells the Deployment which Pods to manage
- `template.metadata.labels` - Labels assigned to each Pod (must match selector)
- `containerPort: 5000` - The port the Flask app listens on inside the container

- Create the web-flask Deployment.
  
```bash
kubectl apply -f web-flask.yaml
```

**Expected Output:**
```text
deployment.apps/web-flask-deploy created
```

- Show the Pods detailed information and learn their IP addresses:

```bash
kubectl get pods -o wide
```

- We get an output like below.

```text
NAME                                READY   STATUS    RESTARTS   AGE   IP           NODE          NOMINATED NODE   READINESS GATES
web-flask-deploy-5b59bc685f-2cwc2   1/1     Running   0          78s   10.244.1.5   kube-worker   <none>           <none>
web-flask-deploy-5b59bc685f-b92fr   1/1     Running   0          78s   10.244.1.4   kube-worker   <none>           <none>
web-flask-deploy-5b59bc685f-r2tb9   1/1     Running   0          78s   10.244.1.3   kube-worker   <none>           <none>
```

**Important:** In the output above, for each Pod the IPs are internal and specific to each instance. If we were to redeploy the application, then each time a new IP will be allocated. This is why we need Services!

We now check that we can ping a Pod inside the cluster.

- Create a `forcurl.yaml` file to create a Pod that can test connectivity inside the cluster.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: forcurl
spec:
  containers:
  - name: forcurl
    image: ondiacademy/forping
    imagePullPolicy: IfNotPresent
  restartPolicy: Always
```

**Note:** `imagePullPolicy: IfNotPresent` means Kubernetes will use a locally cached image if available, otherwise it will pull from the registry.

- Create a `forcurl` pod and log into the container.

```bash
kubectl apply -f forcurl.yaml
kubectl get pods
```

**Expected Output:**
```text
NAME                                READY   STATUS    RESTARTS   AGE
forcurl                             1/1     Running   0          5s
web-flask-deploy-5b59bc685f-2cwc2   1/1     Running   0          2m
web-flask-deploy-5b59bc685f-b92fr   1/1     Running   0          2m
web-flask-deploy-5b59bc685f-r2tb9   1/1     Running   0          2m
```

- Test connectivity to one of the Pods:

```bash
kubectl exec -it forcurl -- sh
/ # ping 10.244.1.3
/ # curl 10.244.1.3:5000
/ # exit
```

- Show the Pods detailed information and learn their IP addresses again.

```bash
kubectl get pods -o wide
```

- Scale the deployment down to zero.

```bash
kubectl scale deploy web-flask-deploy --replicas=0
```

**Expected Output:**
```text
deployment.apps/web-flask-deploy scaled
```

- List the pods again and note that there is no pod in web-flask-deploy.

```bash
kubectl get pods -o wide
```

**Expected Output:**
```text
NAME      READY   STATUS    RESTARTS   AGE
forcurl   1/1     Running   0          2m
```

- Scale the deployment up to three replicas.

```bash
kubectl scale deploy web-flask-deploy --replicas=3
```

- List the pods again and note that the pods have **different IP addresses** now.

```bash
kubectl get pods -o wide
```

**Observation:** The Pod IPs have changed! This demonstrates why we cannot rely on Pod IPs directly.

### Creating a ClusterIP Service

- Get the documentation of `Services` and its fields.

```bash
kubectl explain svc
kubectl explain svc.spec
```

- Create a `web-svc.yaml` file with the following content and explain its fields.

```yaml
apiVersion: v1
kind: Service   
metadata:
  name: web-flask-svc
  labels:
    env: dev
spec:
  type: ClusterIP  
  ports:
  - port: 3000  
    targetPort: 5000
  selector:
    app: web-flask
```

**Field Explanations:**
- `type: ClusterIP` - Default type, makes Service accessible only within the cluster
- `port: 3000` - The port the Service listens on
- `targetPort: 5000` - The port on the Pod (where Flask app is running)
- `selector.app: web-flask` - The Service routes traffic to Pods with this label

**How it works:** When you send traffic to the Service on port 3000, it forwards to port 5000 on the selected Pods.
  
```bash
kubectl apply -f web-svc.yaml
```

**Expected Output:**
```text
service/web-flask-svc created
```

- List the services.

```bash
kubectl get svc -o wide
```

**Expected Output:**
```text
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE   SELECTOR
kubernetes      ClusterIP   10.96.0.1       <none>        443/TCP    4h    <none>
web-flask-svc   ClusterIP   10.98.173.110   <none>        3000/TCP   28m   app=web-flask
```

- Display information about the `web-flask-svc` Service.

```bash
kubectl describe svc web-flask-svc
```

**Expected Output:**
```text
Name:              web-flask-svc
Namespace:         default
Labels:            env=dev
Annotations:       <none>
Selector:          app=web-flask
Type:              ClusterIP
IP Family Policy:  SingleStack
IP Families:       IPv4
IP:                10.109.125.55
IPs:               10.109.125.55
Port:              <unset>  3000/TCP
TargetPort:        5000/TCP
Endpoints:         10.244.1.7:5000,10.244.1.8:5000,10.244.1.9:5000
Session Affinity:  None
Events:            <none>
```

**Important:** Notice the `Endpoints` field - these are the Pod IPs. The Service automatically tracks which Pods match its selector.

- Go to the forcurl pod and test the Service with ClusterIP. 

```bash
kubectl exec -it forcurl -- sh
/ # curl <IP of service web-flask-svc>:3000
/ # ping web-flask-svc 
/ # curl web-flask-svc:3000
```

**Observation:** You can access the Service using either:
1. The Service's ClusterIP: `curl 10.109.125.55:3000`
2. The Service's DNS name: `curl web-flask-svc:3000`

- As we see, Kubernetes services provide automatic DNS resolution. The Service name becomes a DNS entry that resolves to the Service's ClusterIP.

**Key Takeaway:** Even if Pods are deleted and recreated with new IPs, the Service IP and DNS name remain stable!

### NodePort Service Type

- Change the service type of web-flask-svc service to NodePort to use the Node IP and a static port to expose the service outside the cluster. Update `web-svc.yaml`:

```yaml
apiVersion: v1
kind: Service   
metadata:
  name: web-flask-svc
  labels:
    env: dev
spec:
  type: NodePort  
  ports:
  - port: 3000  
    targetPort: 5000
  selector:
    app: web-flask
```

**What changed:** Only the `type` field changed from `ClusterIP` to `NodePort`.

**What NodePort does:** 
- Exposes the Service on each Node's IP at a static port (the NodePort)
- Automatically creates a ClusterIP Service (for internal cluster access)
- Allows external traffic to access the Service via `<NodeIP>:<NodePort>`

- Configure the web-flask-svc service via the apply command.

```bash
kubectl apply -f web-svc.yaml
```

**Expected Output:**
```text
service/web-flask-svc configured
```

- List the services again. Kubernetes exposes the service in a random port within the range 30000-32767 using the Node's primary IP address.

```bash
kubectl get svc -o wide
```

**Expected Output:**
```text
NAME            TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE   SELECTOR
web-flask-svc   NodePort   10.98.173.110   <none>        3000:31234/TCP   30m   app=web-flask
```

**Notice:** The PORT(S) column now shows `3000:31234/TCP`
- `3000` = Internal ClusterIP port
- `31234` = External NodePort (randomly assigned)

- Test the Service from inside the cluster (still works the same way):

```bash
kubectl exec -it forcurl -- sh
/ # curl web-flask-svc:3000
/ # exit
```

- Now you can also access the service from **outside the cluster**:

**Important Security Note:** Before accessing from outside, you need to open the NodePort in your node's security group (AWS Security Group, firewall rules, etc.)

**Steps:**
1. Find your node's public IP:
```bash
kubectl get nodes -o wide
```

2. Open port `31234` (or whatever port was assigned) in your Security Group

3. Access via browser or curl:
```
http://<public-node-ip>:31234
```

- We can visit `http://<public-node-ip>:<node-port>` and access the application. Pay attention to load balancing - refresh the page multiple times and notice the hostname changes (showing different Pods are serving requests).

**Note:** Do not forget to open the Port `<node-port>` in the security group of your node instance.

### Specifying a NodePort

- We can also define a specific NodePort by adding a `nodePort` number to the service YAML file. Update `web-svc.yaml`:

```yaml
apiVersion: v1
kind: Service   
metadata:
  name: web-flask-svc
  labels:
    env: dev
spec:
  type: NodePort 
  ports:
  - nodePort: 30036  
    port: 3000        
    targetPort: 5000
  selector:
    app: web-flask
```

**What changed:** We added `nodePort: 30036` to specify exactly which port we want.

**Valid NodePort range:** 30000-32767 (configurable in kube-apiserver)

- Configure the web-flask-svc service again via the apply command.

```bash
kubectl apply -f web-svc.yaml
```

**Expected Output:**
```text
service/web-flask-svc configured
```

- List the services and notice that the nodeport number is now 30036.

```bash
kubectl get svc -o wide
```

**Expected Output:**
```text
NAME            TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE   SELECTOR
web-flask-svc   NodePort   10.98.173.110   <none>        3000:30036/TCP   35m   app=web-flask
```

- Update your security group to allow port 30036, then access:

```
http://<public-node-ip>:30036
```

### Understanding Endpoints

As Pods come and go (scaling up and down, failures, rolling updates, etc.), the Service dynamically updates its list of Pods. It does this through a combination of the label selector and a construct called an **Endpoint object**.

Each Service that is created automatically gets an associated Endpoint object. This Endpoint object is a dynamic list of all of the Pods that match the Service's label selector.

Kubernetes is constantly evaluating the Service's label selector against the current list of Pods in the cluster. Any new Pods that match the selector get added to the Endpoint object, and any Pods that disappear get removed. This ensures the Service is kept up-to-date as Pods come and go.

**How it works:**
1. Service uses `selector` to find matching Pods
2. Kubernetes creates an Endpoint object with the same name as the Service
3. Endpoint controller constantly watches for Pod changes
4. When Pods are added/removed, Endpoints are automatically updated
5. Service uses the Endpoint list to route traffic

- Get the documentation of `Endpoints` and its fields.

```bash
kubectl explain ep
```

- List the Endpoints.

```bash
kubectl get ep -o wide
```

**Expected Output:**
```text
NAME            ENDPOINTS                                         AGE
kubernetes      192.168.1.100:6443                                5h
web-flask-svc   10.244.1.7:5000,10.244.1.8:5000,10.244.1.9:5000   40m
```

**Notice:** The Endpoints match the Pod IPs we saw earlier when we ran `kubectl get pods -o wide`!

- Scale the deployment up to ten replicas and list the `Endpoints`.

```bash
kubectl scale deploy web-flask-deploy --replicas=10
```

**Expected Output:**
```text
deployment.apps/web-flask-deploy scaled
```

- List the `Endpoints` and explain that the Service has an associated `Endpoint` object with an always-up-to-date list of Pods matching the label selector.

```bash
kubectl get ep -o wide 
```

**Expected Output:**
```text
NAME            ENDPOINTS                                                          AGE
web-flask-svc   10.244.1.10:5000,10.244.1.11:5000,10.244.1.12:5000 + 7 more...   42m
```

**Observation:** The Endpoints automatically updated to include all 10 Pods!

- Verify this by checking Pod IPs:

```bash
kubectl get pods -o wide
```

- Now scale down to 2 replicas:

```bash
kubectl scale deploy web-flask-deploy --replicas=2
kubectl get ep web-flask-svc
```

**Observation:** Endpoints automatically removed the deleted Pods.

**Key Takeaway:** The Endpoint controller continuously monitors Pod changes and keeps the Service's endpoint list current. This is how Services provide stable networking despite Pod churn.

> Open a browser on any node and demonstrate the `load balancing` behavior. (Pay attention to the host IP and node name, and note that `host IPs` and `endpoints` are the same)
>
> http://[public-node-ip]:[node-port]
>
> Refresh the page multiple times and watch the hostname/IP change, showing that traffic is being load-balanced across all backend Pods.

### LoadBalancer Service Type (Cloud Provider Specific)

**Note:** LoadBalancer type is typically used in cloud environments (AWS, GCP, Azure) where the cloud provider can provision an external load balancer.

- Update `web-svc.yaml` to use LoadBalancer type:

```yaml
apiVersion: v1
kind: Service   
metadata:
  name: web-flask-svc
  labels:
    env: dev
spec:
  type: LoadBalancer  
  ports:
  - port: 3000  
    targetPort: 5000
  selector:
    app: web-flask
```

```bash
kubectl apply -f web-svc.yaml
kubectl get svc -o wide
```

**Expected Output (on cloud provider):**
```text
NAME            TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)          AGE
web-flask-svc   LoadBalancer   10.98.173.110   a1234567890abcdef.us-east-1.elb.amazonaws.com                          3000:31234/TCP   45m
```

**What happens:**
- Cloud provider provisions an external load balancer (e.g., AWS ELB/ALB)
- Traffic flows: External LB → NodePort → Service → Pods
- You get a publicly accessible hostname/IP in EXTERNAL-IP field

**Note:** In local clusters (minikube, kind, bare metal), EXTERNAL-IP will remain `<pending>` because there's no cloud provider to create the load balancer.

### Connecting to a Service in a Different Namespace

- Kubernetes has an add-on for DNS (CoreDNS), which creates a DNS record for each Service. The format is:

`<service-name>.<namespace>.svc.cluster.local`

**DNS Resolution Rules:**
- Services within the **same Namespace** can find each other using just the service name (e.g., `web-flask-svc`)
- Services in **different Namespaces** must use the full format: `<service-name>.<namespace-name>` or the FQDN

- Let's understand this with an example.

- First, remove the deployment and service from the default namespace:

```bash
kubectl delete -f web-flask.yaml -f web-svc.yaml
```

**Alternative (if you're in the service-lessons directory):**
```bash
kubectl delete -f .
```

**Expected Output:**
```text
deployment.apps "web-flask-deploy" deleted
service "web-flask-svc" deleted
```

- Create a namespace and name it `demo`.

```bash
kubectl create namespace demo
```

**Expected Output:**
```text
namespace/demo created
```

- Update the `web-flask.yaml` file to deploy in the `demo` namespace:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-flask-deploy
  labels:
    env: dev
  namespace: demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-flask
  template:
    metadata:
      labels:
        app: web-flask
    spec:
      containers:
      - name: web-flask-pod
        image: ondiacademy/cw_web_flask1
        ports:
        - containerPort: 5000
```

**What changed:** Added `namespace: demo` in metadata.

- Update the `web-svc.yaml` file to create the Service in `demo` namespace:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-flask-svc
  namespace: demo
  labels:
    env: dev
spec:
  type: NodePort
  ports:
  - port: 3000
    targetPort: 5000
    nodePort: 30036
  selector:
    app: web-flask
```

**What changed:** Added `namespace: demo` in metadata.

- Create deployment and service:

```bash
kubectl apply -f web-flask.yaml -f web-svc.yaml
```

**Expected Output:**
```text
deployment.apps/web-flask-deploy created
service/web-flask-svc created
```

- Show all namespaces:

```bash
kubectl get ns
```

**Expected Output:**
```text
NAME              STATUS   AGE
default           Active   6h
demo              Active   2m
kube-node-lease   Active   6h
kube-public       Active   6h
kube-system       Active   6h
```

- List objects in both `demo` and `default` namespaces:

```bash
kubectl get deploy -n demo
kubectl get pod -n demo
kubectl get svc -n demo
```

**Expected Output (demo namespace):**
```text
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
web-flask-deploy   3/3     3            3           1m

NAME                                READY   STATUS    RESTARTS   AGE
web-flask-deploy-5b59bc685f-xxxxx   1/1     Running   0          1m
web-flask-deploy-5b59bc685f-yyyyy   1/1     Running   0          1m
web-flask-deploy-5b59bc685f-zzzzz   1/1     Running   0          1m

NAME              TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
web-flask-svc     NodePort   10.96.100.50   <none>        3000:30036/TCP   1m
```

```bash
kubectl get pod
kubectl get svc
```

**Expected Output (default namespace):**
```text
NAME      READY   STATUS    RESTARTS   AGE
forcurl   1/1     Running   0          15m

NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   6h
```

**Observation:** The `forcurl` Pod is in the `default` namespace, while our Flask app is in the `demo` namespace.

- Log into the forcurl container and try to access `web-flask-svc` in the `demo` namespace:

```bash
kubectl exec -it forcurl -- sh
```

**Test 1: Try using just the service name (will FAIL):**
```bash
/ # curl web-flask-svc:3000
```
**Result:** This will fail with "could not resolve host" because we're in different namespaces.

**Test 2: Use namespace-qualified name:**
```bash
/ # curl web-flask-svc.demo:3000
```
**Result:** Success! This works because we specified the namespace.

**Test 3: Use Fully Qualified Domain Name (FQDN):**
```bash
/ # curl web-flask-svc.demo.svc.cluster.local:3000
```
**Result:** Also works! This is the complete DNS name.

**DNS Name Breakdown:**
- `web-flask-svc` = Service name
- `demo` = Namespace name
- `svc` = Indicates this is a Service
- `cluster.local` = Cluster domain (default)

**Key Takeaways:**
- Same namespace: Use just `<service-name>`
- Different namespace: Use `<service-name>.<namespace>`
- Full FQDN: `<service-name>.<namespace>.svc.cluster.local`

- Exit the container:

```bash
/ # exit
```

- Delete all objects:

```bash
kubectl delete -f web-flask.yaml -f web-svc.yaml
kubectl delete ns demo
```

**Expected Output:**
```text
deployment.apps "web-flask-deploy" deleted
service "web-flask-svc" deleted
namespace "demo" deleted
```

**Note:** Deleting a namespace automatically deletes all resources within it.

## Part 3 - Service Types Summary

### ClusterIP (Default)
- **Use case:** Internal cluster communication only
- **Access:** Only from within the cluster
- **DNS:** `<service-name>` or `<service-name>.<namespace>.svc.cluster.local`
- **Example:** Microservices talking to each other, databases

### NodePort
- **Use case:** Expose service on each node's IP at a static port
- **Access:** From outside the cluster via `<NodeIP>:<NodePort>`
- **Port range:** 30000-32767 (default)
- **Example:** Development/testing environments, small deployments
- **Note:** Each service gets its own port on ALL nodes

### LoadBalancer
- **Use case:** Cloud environments (AWS, GCP, Azure)
- **Access:** Via cloud provider's load balancer (gets external IP/hostname)
- **Example:** Production applications needing external access
- **Note:** Costs associated with cloud load balancer
- **How it works:** Creates NodePort + provisions external LB → NodePort → Service → Pods

### ExternalName
- **Use case:** Map a service to an external DNS name
- **Example:** Accessing external database, third-party API
```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: mydb.example.com
```
- **Note:** No selector needed, just returns CNAME record

## Troubleshooting Tips

### Service Not Working?

**Check 1: Verify Endpoints exist**
```bash
kubectl get ep <service-name>
```
If empty, the selector doesn't match any Pods.

**Check 2: Verify Pod labels**
```bash
kubectl get pods --show-labels
```
Do the Pod labels match the Service selector?

**Check 3: Verify Pod is ready**
```bash
kubectl get pods
```
Pod must be in Running state and READY should show 1/1.

**Check 4: Test from inside cluster first**
```bash
kubectl run test --image=busybox --rm -it -- sh
/ # wget -O- http://<service-name>:<port>
```

**Check 5: Check Service details**
```bash
kubectl describe svc <service-name>
```
Look for Endpoints, Selector, and Events sections.

**Check 6: Port mismatch?**
- `port` = Service listens on this port
- `targetPort` = Pod listens on this port (must match containerPort in Deployment)
- `nodePort` = External access port (NodePort/LoadBalancer only)

**Common mistakes:**
- Selector doesn't match Pod labels (typo, wrong label)
- Wrong targetPort (doesn't match containerPort)
- Container not actually listening on the port
- Network policies blocking traffic
- CoreDNS not running: `kubectl get pods -n kube-system`

## Summary

In this hands-on training, you learned:

✅ How Kubernetes Services provide stable networking for dynamic Pods

✅ Service discovery through CoreDNS (automatic DNS resolution)

✅ Three main Service types:
   - **ClusterIP**: Internal cluster communication
   - **NodePort**: External access via node IP and static port
   - **LoadBalancer**: Cloud provider load balancer (external access)

✅ How Endpoints track Pod changes automatically

✅ Cross-namespace service communication using DNS

✅ How to troubleshoot service connectivity issues

**Key Concepts to Remember:**
- Pods are ephemeral (they get new IPs when recreated)
- Services provide stable IPs and DNS names
- Label selectors connect Services to Pods
- Endpoint controllers keep service endpoints updated
- DNS makes services discoverable
- Different service types for different use cases

## Additional Resources

- [Kubernetes Services Official Documentation](https://kubernetes.io/docs/concepts/services-networking/service/)
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

---

**End of Hands-on Training**
