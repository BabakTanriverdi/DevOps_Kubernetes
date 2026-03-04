# Hands-on EKS-02: Gateway API and Dynamic Volume Provisioning

The purpose of this hands-on training is to give students the knowledge of Dynamic Volume Provisioning and Gateway API.

> ⚠️ **Why Gateway API?**
> Kubernetes is no longer actively developing the Ingress resource. The official recommendation is now to use the **Gateway API**. Compared to Ingress, Gateway API offers far more flexible, powerful, and standardized traffic management.

## Learning Outcomes

At the end of this hands-on training, students will be able to;

- Learn to Create and Manage EKS Cluster with eksctl.

- Explain the need for persistent data management

- Learn PersistentVolumes and PersistentVolumeClaims

- Understand the Gateway API and Gateway Controller Usage

## Outline

- Part 1 - Installing kubectl and eksctl on Amazon Linux 2023

- Part 2 - Creating the Kubernetes Cluster on EKS

- Part 3 - Gateway API

- Part 4 - Dynamic Volume Provisioning


## Prerequisites

1. AWS CLI with Configured Credentials

2. kubectl installed

3. eksctl installed

For information on installing or upgrading eksctl, see [Installing or upgrading eksctl.](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html#installing-eksctl)

## Part 1 - Installing kubectl and eksctl on Amazon Linux 2023

### Install kubectl

- Launch an AWS EC2 instance of Amazon Linux 2023 AMI with security group allowing SSH.

- Connect to the instance with SSH.

- Update the installed packages and package cache on your instance.

```bash
sudo dnf update -y
```

- Download the Amazon EKS vended kubectl binary.

```bash
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.34.1/2025-09-19/bin/linux/amd64/kubectl
```

- Apply execute permissions to the binary.

```bash
chmod +x ./kubectl
```

- Copy the binary to a folder in your PATH. If you have already installed a version of kubectl, then we recommend creating a $HOME/bin/kubectl and ensuring that $HOME/bin comes first in your $PATH.

```bash
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
```

- (Optional) Add the $HOME/bin path to your shell initialization file so that it is configured when you open a shell.

```bash
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
```

- After you install kubectl, you can verify its version with the following command:

```bash
kubectl version --client
```

### Install eksctl

- Download and extract the latest release of eksctl with the following command.

```bash
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
```

- Move and extract the binary to /tmp folder.

```bash
tar -xzf eksctl_$(uname -s)_amd64.tar.gz -C /tmp && rm eksctl_$(uname -s)_amd64.tar.gz
```

- Move the extracted binary to /usr/local/bin.

```bash
sudo mv /tmp/eksctl /usr/local/bin
```

- Test that your installation was successful with the following command.

```bash
eksctl version
```

## Part 2 - Creating the Kubernetes Cluster on EKS

- Configure AWS credentials. Or you can attach `AWS IAM Role` to your EC2 instance.

```bash
aws configure
```

- Create an EKS cluster via `eksctl`. It will take a while.

```bash
eksctl create cluster --region us-east-1 --version 1.34 --zones us-east-1a,us-east-1b,us-east-1c --node-type t3a.medium --nodes 2 --nodes-min 2 --nodes-max 3 --name cw-cluster
```

### Alternative way (Including SSH connection to worker node)

- If needed, create an SSH key with the command `ssh-keygen -f ~/.ssh/id_rsa`.

```bash
eksctl create cluster \
 --name cw-cluster \
 --region us-east-1 \
 --version 1.34 \
 --zones us-east-1a,us-east-1b,us-east-1c \
 --nodegroup-name my-nodes \
 --node-type t3a.medium \
 --nodes 2 \
 --nodes-min 2 \
 --nodes-max 3 \
 --ssh-access \
 --ssh-public-key  ~/.ssh/id_rsa.pub \
 --managed
```

- Explain the default values.

```bash
eksctl create cluster --help
```

- Show the AWS `eks service` on AWS Management Console and explain `eksctl-my-cluster-cluster` stack on `cloudformation service`.


## Part 3 - Gateway API

- Create a folder and name it gateway-lesson.

```bash
mkdir gateway-lesson
cd gateway-lesson
```

- Create a file named `clarusshop.yaml` for the clarusshop deployment object.

```yaml
apiVersion: apps/v1 
kind: Deployment 
metadata:
  name: clarusshop-deploy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: clarusshop 
  template: 
    metadata:
      labels:
        app: clarusshop
    spec:
      containers:
      - name: clarusshop-pod
        image: clarusway/clarusshop
        ports:
        - containerPort: 80
```

- Create a file named `clarusshop-svc.yaml` for the clarusshop service object.

> ⚠️ When using Gateway API, the service type should be `ClusterIP`. `NodePort` is not required.

```yaml
apiVersion: v1
kind: Service   
metadata:
  name: clarusshop-svc
  labels:
    app: clarusshop
spec:
  type: ClusterIP
  ports:
  - port: 80  
    targetPort: 80
  selector:
    app: clarusshop
```

- Create a file named `account.yaml` for the account deployment object.

```yaml
apiVersion: apps/v1 
kind: Deployment 
metadata:
  name: account-deploy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: account
  template: 
    metadata:
      labels:
        app: account
    spec:
      containers:
      - name: account-pod
        image: clarusway/clarusshop:account
        ports:
        - containerPort: 80
```

- Create a file named `account-svc.yaml` for the account service object.

```yaml
apiVersion: v1
kind: Service   
metadata:
  name: account-svc
  labels:
    app: account
spec:
  type: ClusterIP
  ports:
  - port: 80  
    targetPort: 80
  selector:
    app: account
```

- Create the objects.

```bash
kubectl apply -f .
```

### Gateway API

- Briefly explain Gateway API and Gateway Controller. For additional information, a few portals can be visited, like;

  - https://gateway-api.sigs.k8s.io/
  - https://docs.nginx.com/nginx-gateway-fabric/

- Gateway API is built around three core resources:

| Resource | Role |
|---|---|
| `GatewayClass` | Defines which controller to use (nginx, istio, etc.) |
| `Gateway` | The "door" that listens for incoming traffic — defines port and protocol |
| `HTTPRoute` | Defines which service an incoming request should be routed to |

- Install the Gateway API CRDs. The `--server-side=true` flag is required because the CRD manifests are too large for a standard apply.

```bash
kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
```

- Install the NGINX Gateway Fabric controller.

```bash
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v2.4.2/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v2.4.2/deploy/default/deploy.yaml
```

- Verify the controller is running.

```bash
kubectl get pods -n nginx-gateway
kubectl get gatewayclass
```

- Create a file named `gateway.yaml` for the Gateway object.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: clarusshop-gateway
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    protocol: HTTP
    port: 80
```

- Create the Gateway object.

```bash
kubectl apply -f gateway.yaml
kubectl get gateway
```

- Create a file named `httproute.yaml` for the HTTPRoute object.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: clarusshop-route
spec:
  parentRefs:
  - name: clarusshop-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /account
    backendRefs:
    - name: account-svc
      port: 80
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: clarusshop-svc
      port: 80
```

- Create the HTTPRoute object.

```bash
kubectl apply -f httproute.yaml
kubectl get httproute
```

- Check the Gateway to get the external address.

```bash
kubectl get gateway clarusshop-gateway
```

- You will get an output like below.

```bash
NAME                  CLASS   ADDRESS                                                                    READY   AGE
clarusshop-gateway    nginx   afdfe2adcb6934b4abb645258b8f73d2-501976fbe439549f.elb.us-east-1.amazonaws.com   True    12s
```

- Use the address to reach the services.

```bash
curl afdfe2adcb6934b4abb645258b8f73d2-501976fbe439549f.elb.us-east-1.amazonaws.com
curl afdfe2adcb6934b4abb645258b8f73d2-501976fbe439549f.elb.us-east-1.amazonaws.com/account
```

- Delete everything.

```bash
kubectl delete -f .
```

#### Host

- We can define a hostname for the HTTPRoute. Update the `httproute.yaml` file as below.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: clarusshop-route
spec:
  parentRefs:
  - name: clarusshop-gateway
  hostnames:
  - "clarusshop.clarusway.us"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /account
    backendRefs:
    - name: account-svc
      port: 80
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: clarusshop-svc
      port: 80
```

- Apply the HTTPRoute object.

```bash
kubectl apply -f httproute.yaml
kubectl get httproute
```

- To reach the application with `host` name, create a `clarusshop.clarusway.us` record for the address (network load balancer) in the `route53` service.

- Apply all files.

```bash
kubectl apply -f .
```

- You can reach the application using the curl command.

```bash
curl clarusshop.clarusway.us
curl clarusshop.clarusway.us/account
```

- Delete all objects.

```bash
kubectl delete -f .
```

#### Name-based virtual hosting

- Create a folder named `virtual-hosting`.

```bash
mkdir virtual-hosting && cd virtual-hosting
```

- Create two pods and services for nginx and Apache.

```bash
kubectl run mynginx --image=nginx --port=80 --expose
kubectl run myapache --image=httpd --port=80 --expose
kubectl get po,svc
```

- Create a Gateway file named `virtual-gateway.yaml`.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: virtual-gateway
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    protocol: HTTP
    port: 80
```

- Create an HTTPRoute file named `nginx-route.yaml` for nginx.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: nginx-route
spec:
  parentRefs:
  - name: virtual-gateway
  hostnames:
  - "nginx.clarusway.us"
  rules:
  - backendRefs:
    - name: mynginx
      port: 80
```

- Create an HTTPRoute file named `apache-route.yaml` for Apache.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: apache-route
spec:
  parentRefs:
  - name: virtual-gateway
  hostnames:
  - "apache.clarusway.us"
  rules:
  - backendRefs:
    - name: myapache
      port: 80
```

- Create all objects.

```bash
kubectl apply -f .
kubectl get gateway,httproute
```

- You will get an output like below.

```bash
NAME                                        CLASS   ADDRESS                                                                    READY   AGE
gateway.gateway.networking.k8s.io/virtual-gateway   nginx   afdfe2adcb6934b4abb645258b8f73d2-501976fbe439549f.elb.us-east-1.amazonaws.com   True    6s

NAME                                              HOSTNAMES                 AGE
httproute.gateway.networking.k8s.io/nginx-route   ["nginx.clarusway.us"]    6s
httproute.gateway.networking.k8s.io/apache-route  ["apache.clarusway.us"]   6s
```

- To reach the application with `host` name, create `nginx.clarusway.us` and `apache.clarusway.us` records for address (network load balancer) in `route53` service.

- Check the host address.

```bash
curl nginx.clarusway.us
curl apache.clarusway.us
```

- Delete all objects.

```bash
kubectl delete -f .
```

## Part 4 - Dynamic Volume Provisioning

### The Amazon Elastic Block Store (Amazon EBS) Container Storage Interface (CSI) driver

- The Amazon Elastic Block Store (Amazon EBS) Container Storage Interface (CSI) driver allows Amazon Elastic Kubernetes Service (Amazon EKS) clusters to manage the lifecycle of Amazon EBS volumes for persistent volumes.

- The Amazon EBS CSI driver isn't installed when you first create a cluster. To use the driver, you must add it as an Amazon EKS add-on or as a self-managed add-on. 

- Install the Amazon EBS CSI driver. For instructions on how to add it as an Amazon EKS add-on, see Managing the [Amazon EBS CSI driver as an Amazon EKS add-on](https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html).

### Creating an IAM OIDC provider for your cluster

- To use AWS EBS CSI, it is required to have an AWS Identity and Access Management (IAM) OpenID Connect (OIDC) provider for your cluster. 

- Determine whether you have an existing IAM OIDC provider for your cluster. Retrieve your cluster's OIDC provider ID and store it in a variable.

```bash
oidc_id=$(aws eks describe-cluster --name cw-cluster --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
```

- Determine whether an IAM OIDC provider with your cluster's ID is already in your account.

```bash
aws iam list-open-id-connect-providers | grep $oidc_id
```
If output is returned from the previous command, then you already have a provider for your cluster and you can skip the next step. If no output is returned, then you must create an IAM OIDC provider for your cluster.

- Create an IAM OIDC identity provider for your cluster with the following command. Replace my-cluster with your own value.

```bash
eksctl utils associate-iam-oidc-provider --region=us-east-1 --cluster=cw-cluster --approve
```

### Creating the Amazon EBS CSI driver IAM role for service accounts

- The Amazon EBS CSI plugin requires IAM permissions to make calls to AWS APIs on your behalf. 

- When the plugin is deployed, it creates and is configured to use a service account that's named ebs-csi-controller-sa. The service account is bound to a Kubernetes clusterrole that's assigned the required Kubernetes permissions.

#### To create your Amazon EBS CSI plugin IAM role with eksctl

- Create an IAM role and attach the required AWS managed policy with the following command. Replace cw-cluster with the name of your cluster. The command deploys an AWS CloudFormation stack that creates an IAM role, attaches the IAM policy to it, and annotates the existing ebs-csi-controller-sa service account with the Amazon Resource Name (ARN) of the IAM role.

```bash
eksctl create iamserviceaccount \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster cw-cluster \
    --role-name AmazonEKS_EBS_CSI_DriverRole \
    --role-only \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --region us-east-1 \
    --approve
```

### Adding the Amazon EBS CSI add-on

#### To add the Amazon EBS CSI add-on using eksctl

- Run the following command. Replace cw-cluster with the name of your cluster, 111122223333 with your account ID, and AmazonEKS_EBS_CSI_DriverRole with the name of the IAM role created earlier.

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
eksctl create addon --name aws-ebs-csi-driver --cluster cw-cluster --service-account-role-arn arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole --force
```

- Firstly, check the StorageClass object in the cluster. 

```bash
kubectl get sc

kubectl describe sc/gp2
```

- Create a `storage-class` directory and change directory.

```bash
cd && mkdir storage-class && cd storage-class
```

- Create a StorageClass with the following settings.

```bash
vi storage-class.yaml
```

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: myaws-sc
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp2
  fsType: ext4           
```

```bash
kubectl apply -f storage-class.yaml
```

- Explain the default storageclass

```bash
kubectl get storageclass
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  75m
myaws-sc        ebs.csi.aws.com         Delete          WaitForFirstConsumer   false                  7s
```

- Create a persistentvolumeclaim with the following settings and show that the new volume is created on the AWS management console.

```bash
vi clarus-pv-claim.yaml
```
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: clarus-pv-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: myaws-sc
```

```bash
kubectl apply -f clarus-pv-claim.yaml
```

- List the PV and PVC and explain the connections.

```bash
kubectl get pv,pvc
```
- You will see an output like this

```text
NAME                    STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/clarus-pv-claim   Pending                    myaws-sc       <unset>                 10s
```

- Create a pod with the following settings.

```bash
vi pod-with-dynamic-storage.yaml
```
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-aws
  labels:
    app : web-nginx
spec:
  containers:
  - image: nginx:latest
    ports:
    - containerPort: 80
    name: test-aws
    volumeMounts:
    - mountPath: /usr/share/nginx/html
      name: aws-pd
  volumes:
  - name: aws-pd
    persistentVolumeClaim:
      claimName: clarus-pv-claim
```

```bash
kubectl apply -f pod-with-dynamic-storage.yaml
```

- Enter the pod and see that EBS is mounted to  /usr/share/nginx/html path.

```bash
kubectl exec -it test-aws -- bash
```
- You will see an output like this

```bash
root@test-aws:/# df -h
Filesystem      Size  Used Avail Use% Mounted on
overlay          80G  3.7G   77G   5% /
tmpfs            64M     0   64M   0% /dev
tmpfs           1.9G     0  1.9G   0% /sys/fs/cgroup
/dev/nvme0n1p1   80G  3.7G   77G   5% /etc/hosts
shm              64M     0   64M   0% /dev/shm
/dev/nvme1n1    974M   24K  958M   1% /usr/share/nginx/html
tmpfs           3.3G   12K  3.3G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs           1.9G     0  1.9G   0% /proc/acpi
tmpfs           1.9G     0  1.9G   0% /sys/firmware
```

- Delete the storageclass that we created.

```bash
kubectl get storageclass
```
- You will see an output like this

```text
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
myaws-sc        ebs.csi.aws.com         Delete          WaitForFirstConsumer   false                  71m
gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  4h10m
```

```bash
kubectl delete storageclass myaws-sc
```

```bash
kubectl get storageclass
```

- You will see an output like this

```text
NAME                    PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE     ALLOWVOLUMEEXPANSION   AGE
gp2 (default)            kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer  false                  52m
```

- Delete the pod

```bash
kubectl delete -f pod-with-dynamic-storage.yaml
kubectl delete -f clarus-pv-claim.yaml
```

- Delete the cluster

```bash
eksctl get cluster --region us-east-1
```
- You will see an output like this

```text
NAME            REGION
cw-cluster      us-east-1
```
```bash
eksctl delete cluster cw-cluster --region us-east-1
```

- Do not forget to delete related EBS volumes.
