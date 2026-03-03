# Hands-on EKS-01: Creating and Managing a Kubernetes Cluster with AWS EKS

The purpose of this hands-on training is to give students the knowledge of how to use AWS Elastic Kubernetes Service

## Learning Outcomes

At the end of this hands-on training, students will be able to;

- Learn to Create and Manage an EKS Cluster with Worker Nodes

## Outline

- Part 1 - Creating the Kubernetes Cluster on EKS

- Part 2 - Creating a kubeconfig file

- Part 3 - Adding Worker Nodes to the Cluster

- Part 4 - Configuring Cluster Autoscaler

- Part 5 - Deploying a Sample Application

## Prerequisites

- Launch an AWS EC2 instance of Amazon Linux 2023 AMI with a security group allowing SSH.

- Connect to the instance with SSH.

- Update the installed packages and package cache on your instance.

```bash
sudo dnf update -y
```

- Install eksctl

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

- Test if your installation was successful with the following command.

```bash
eksctl version
```

- Install kubectl

*** Download the Amazon EKS vendor's kubectl binary that is compatible with the Kubernetes cluster version. For instructions, see [Installing or updating kubectl](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html).

```bash
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.33.5/2025-11-13/bin/linux/amd64/kubectl
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
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
```

- After installing ```kubectl```, you can verify its version with the following command:

```bash
kubectl version --client
```

- Configure AWS credentials.

```bash
aws configure
```

- AWS cli configuration

```bash
  aws configure
  AWS Access Key ID [None]: xxxxxxx
  AWS Secret Access Key [None]: xxxxxxxx
  Default region name [None]: us-east-1
  Default output format [None]: json
```

- Verify that you can see your cluster listed when authenticated

```bash
aws eks list-clusters
{
  "clusters": []
}
```

## Part 1 - Creating the Kubernetes Cluster on EKS

1. Direct the students to the AWS EKS Service webpage. 

2. Give a general description of the page and *****the pricing***** of the services.

- https://aws.amazon.com/eks/pricing/

3. Select ```Cluster``` on the left-hand menu and click on the "Create cluster" button. You will be directed to the ```Configure cluster``` page:

    - Give general descriptions about the page and the steps of creating the cluster.

    - Fill the ```Name``` and ```Kubernetes version``` fields. (Ex: MyCluster, 1.29)

        <i>Mention the durations for minor version support and the approximate release frequency.</i>

    - On the ```Cluster Service Role``` field, give a general description about why we need this role. 

    - Create EKS Cluster Role with ```EKS - Cluster``` use case and ```AmazonEKSClusterPolicy```.

        - EKS Cluster Role:
           - use case   :  ```EKS - Cluster``` 
           - permissions: ```AmazonEKSClusterPolicy```.

    - Select the recently created role, back on the ```Cluster Service Role``` field.

    - Proceed to the ```Secrets Encryption``` field. 
    
    - Activate the field, give a general description about ```KMS Service```, and describe where we use those keys and give an example about a possible key.

    - Deactivate the ```Secrets Encryption``` field and keep it as is.

    - Proceed to the next step (Specify Networking).

4. On the ```Specify Networking``` page's ```Networking field```:

    - Select the default VPC and all public subnets.

        <i>Explain the necessity of using a dedicated VPC for the cluster.</i>

    - Select the default VPC security group (SSH and HTTPS must be allowed) or create one with SSH connection and HTTPS. 

        <i>Explain the necessity of using a dedicated securitygroup for the cluster.</i>

    - Proceed to ```Cluster Endpoint Access``` field.

    - Give a general description of the options in the field.

    - Explain ```Advanced Settings```.

    - Select ```Public and Private``` option on the field.

    - Proceed to the next step (Configure Logging).

5. On the ```Configure Logging``` page:

    - Give general descriptions about the logging options.

    - Proceed to the final step (Review and create).

6. On the ```Review and create``` page:

    - Create the cluster.


## Part 2 - Creating a kubeconfig file

1. Give general descriptions about what ```config file``` is.

2. Verify that you can see your cluster listed when authenticated

```bash
aws eks list-clusters
{
  "clusters": [
    "my-cluster"
  ]
}
```

3. Show the content of the $HOME directory, including hidden files and folders. If there is a ```.kube``` directory, show what it has inside.  

4. Run the command
```bash
aws eks --region us-east-1 update-kubeconfig --name my-cluster
``` 

5. Explain what the above command does.

6. Then run the command on your terminal
```bash
kubectl get svc
```
You should see the output below
```bash
NAME             TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
svc/kubernetes   ClusterIP   10.100.0.1   <none>        443/TCP   1m
```
7. Run the command below to show that there is no node for now.
```bash
kubectl get node
```
8. Show again the content of the $HOME directory, including hidden files and folders. Find the ```config``` file inside ```.kube``` directory. Then show the content of the file.


## Part 3 - Adding Worker Nodes to the Cluster

1. Get to the cluster page that was recently created.

2. Wait until seeing the ```ACTIVE``` status for the cluster.

```bash
aws eks describe-cluster --name my-cluster --query cluster.status
  "ACTIVE"
```

3. On the cluster page, click on ```Compute``` tab and ```Add Node Group``` button.

4. On the ```Configure node group``` page:

    - Give a unique name for the managed node group.

    - For the node's IAM Role, go to the IAM console and create a new role with ```EC2 - Common``` use case having the policies of ```AmazonEKSWorkerNodePolicy, AmazonEC2ContainerRegistryReadOnly, AmazonEKS_CNI_Policy```.
    
        - ```Use case:    EC2 ```
        - ```Policies: AmazonEKSWorkerNodePolicy, AmazonEC2ContainerRegistryReadOnly, AmazonEKS_CNI_Policy```
    
        <i>Give a short description of why we need these policies.</i>
        <i>Explain the necessity of using a dedicated IAM Role.</i>

    -  Proceed to the next page.

5. On the ```Set compute and scaling configuration``` page:
 
    - Choose the appropriate AMI type for non-GPU instances. (Amazon Linux 2 (AL2_x86_64))

    - Choose ```t3.medium``` as the instance type.

        <i>Explain why we can't use</i> ```t2.micro```.
    - Choose appropriate options for other fields. (3 nodes are enough for maximum, 2 nodes for minimum, and desired sizes.)

    - Proceed to the next step.

6. On the ```Specify networking``` page:

    - Choose the subnets to launch your nodes.
    
    - Allow remote access to your nodes.
    <i>Mention that if we don't allow remote access, it's not possible to enable it after the node group is created.</i>
    
    - Select your SSH Key for the connection to your nodes.
    
    - You can also limit the IPs for the connection.

    - Proceed to the next step. Review and create the ```Node Group```.

7. Run the command below on your local.
```bash
kubectl get nodes --watch
```

8. Show the newly created EC2 instances.


## Part 4 - Configuring Cluster Autoscaler

1. Explain what ```Cluster Autoscaler``` is and why we need it.

2. Create a policy for `Cluster-Autoscaler` pod, with the following content. You can name it as ClusterAutoscalerPolicy.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
} 
```


3. Download the "cluster-autoscaler" components and update.

```bash
cd && mkdir cluster-autoscaler && cd cluster-autoscaler

curl -O https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```
Replace <CLUSTER NAME> value with your cluster name, update the image version `registry.k8s.io/autoscaling/cluster-autoscaler:v1.xx.y` (e.g.:v1.33.0) and add the following command option ```--skip-nodes-with-system-pods=false``` to the command section under ```spec.containers```.

- Note : from vim editor you can edit
kubectl -n kube-system edit deployment.apps/cluster-autoscaler

**** Find an appropriate version of your cluster autoscaler in the [link](https://github.com/kubernetes/autoscaler/releases). The version number should start with version number of the cluster Kubernetes version. For example, if you have selected the Kubernetes version 1.29, you should find something like ```1.29.0```.

4. IRSA Setup for Autoscaler

To enable secure AWS access for the Cluster Autoscaler, we use IAM Roles for Service Accounts (IRSA). This allows the autoscaler pod to assume an IAM role without storing AWS credentials inside the container.

- Associate an OIDC provider with your EKS cluster (one-time setup):
```bash
    eksctl utils associate-iam-oidc-provider \
      --region us-east-1 \
      --cluster my-cluster \
      --approve
```

- Create the service account with attached IAM policy:
```bash
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    eksctl create iamserviceaccount \
      --cluster my-cluster \
      --namespace kube-system \
      --name cluster-autoscaler \
      --attach-policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/ClusterAutoscalerPolicy \
      --approve
```

- Check that the service account file is already in your Cluster Autoscaler in the Deployment:

```yaml
    spec:
      template:
        spec:
          serviceAccountName: cluster-autoscaler
```

*** Once deployed, the Cluster Autoscaler will assume the IAM role automatically using IRSA!

5. Apply and annotate the deployment with the following commands.


```bash
kubectl apply -f cluster-autoscaler-autodiscover.yaml
```
*** Monitor created resources!


*** `safe-to-evict="false"` well-known annotation marks the pod as critical to autoscaling — Kubernetes should avoid evicting it.

```bash
kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false"
```

## Part 5 - Deploying a Sample Application

1. Create a `myapp.yml` file in your local environment with the following content.

```bash
cd && mkdir test-cluster-autoscaler && cd test-cluster-autoscaler && touch testing-cas.yaml
```

```yaml
kind: Namespace
apiVersion: v1
metadata:
   name: my-namespace
   labels:
      app: container-info
---
apiVersion: v1
kind: Service
metadata:
   name: container-info-svc
   namespace: my-namespace
   labels:
      app: container-info
spec:
   type: LoadBalancer
   ports:
      - protocol: TCP
        port: 80
        nodePort: 30300
        targetPort: 80
   selector:
      app: container-info
--- 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: container-info-deploy
  namespace: my-namespace
  labels:
    app: container-info
spec:
  replicas: 3
  selector:
    matchLabels:
      app: container-info
  template:
    metadata:
      labels:
        app: container-info
    spec:
      containers:
      - name: container-info
        image: ondiacademy/container-info:1.0
        ports:
        - containerPort: 80
```

2. Deploy the application with the following command.

```bash
kubectl apply -f testing-cas.yaml
```

3. Run the command below.

```bash
kubectl -n my-namespace get svc
```

4. In case the service remains pending, then analyze it. 

```bash
kubectl describe service container-info-svc -n my-namespace
```

Show the warning: "Error creating load balancer (will retry): failed to ensure load balancer for service default/guestbook: could not find any suitable subnets for creating the ELB"

5. Go to this [link](https://aws.amazon.com/tr/premiumsupport/knowledge-center/eks-vpc-subnet-discovery/). Explain that it is necessary to tag selected subnets as follows:

- Key: kubernetes.io/cluster/<cluster-name>
- Value: shared

6. Go to the VPC service on the AWS console and select "subnets". On the ```Subnets``` page, select the "Tags" tab and add this tag:

- Key: kubernetes.io/cluster/<cluster-name>
- Value: shared

7. Describe the service object and analyze it.

```bash
kubectl describe service container-info-svc -n my-namespace
```

8. Get the ```External IP``` value from the previous command's output and visit that IP.

9. For scale-up, edit the deployment. Change "replicas=30" in `myapp.yaml` file. Save the file.

```bash
kubectl edit deploy container-info-deploy -n my-namespace
```

10. Watch the pods while creating. Show that some pods are pending state.

```bash
kubectl get po -n my-namespace -w
```

11. Describe one of the pending pods. Show that there is no resource to run pods. So cluster-autoscaler scales out and create one more node.

```bash
kubectl describe pod container-info-deploy-xxxxxx -n my-namespace
kubectl get nodes
```

12. After cleaning up `worker nodes` and `cluster`, delete the `LoadBalancer` manually.