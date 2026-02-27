# Hands-on Kubernetes-05: Managing Secrets and ConfigMaps

## Purpose

This hands-on training provides practical knowledge of Kubernetes Secrets and ConfigMaps for secure configuration management.

## Learning Outcomes

By the end of this training, you will be able to:

- Understand and explain Kubernetes Secrets
- Securely share sensitive data (passwords, tokens, keys) using Secrets
- Manage application configuration in Kubernetes using ConfigMaps

## Outline

- **Part 1** - Setting up the Kubernetes Cluster
- **Part 2** - Kubernetes Secrets
- **Part 3** - ConfigMaps in Kubernetes

---

## Part 1 - Setting up the Kubernetes Cluster

### Cluster Setup

Launch a Kubernetes Cluster of Ubuntu 22.04 with two nodes (one master, one worker) using the [Cloudformation Template to Create Kubernetes Cluster](../S2-kubernetes-02-basic-operations/cfn-template-to-create-k8s-cluster.yml).

> **Note:** Once the master node is up and running, the worker node automatically joins the cluster.

> **Alternative:** If you have issues with the Kubernetes cluster, you can use the playground at: https://killercoda.com/playgrounds

### Verify Installation

Check if Kubernetes is running and nodes are ready:

```bash
kubectl cluster-info
kubectl get no
```

---

## Part 2 - Kubernetes Secrets

### Creating Secrets Using kubectl

Secrets contain sensitive user credentials required by Pods to access databases or services. For example, a database connection requires a username and password.

#### Create Credential Files

```bash
# Create files for the example
echo -n 'admin' > ./username.txt
echo -n '1f2d1e2e67df' > ./password.txt
```

> **Note:** The `-n` flag prevents outputting a trailing newline.

#### Create Secret from Files

The `kubectl create secret` command packages files into a Secret object:

```bash
kubectl create secret generic --help
kubectl create secret generic db-user-pass --from-file=./username.txt --from-file=./password.txt
```

**Output:**
```bash
secret/db-user-pass created
```

#### Using Custom Key Names

You can set custom key names instead of using filenames:

```bash
kubectl create secret generic db-user-pass-key \
  --from-file=username=./username.txt \
  --from-file=password=./password.txt
```

#### Create Secret from Directory

```bash
kubectl create secret generic my-secret --from-file=/home/ubuntu/Lesson
```

#### Special Characters in Secrets

> **Important:** Special characters like `$`, `\`, `*`, `=`, and `!` require escaping. The easiest way is to use single quotes:

```bash
kubectl create secret generic dev-db-secret \
  --from-literal=username=devuser \
  --from-literal=password='S!B\*d$zDsb='
```

> **Note:** You don't need to escape special characters when using `--from-file`.

### Viewing Secrets

#### List Secrets

```bash
kubectl get secrets
```

**Output:**
```bash
NAME                  TYPE                                  DATA      AGE
db-user-pass          Opaque                                2         51s
```

#### Describe Secret

```bash
kubectl describe secrets/db-user-pass
kubectl get secrets/db-user-pass -o yaml
```

> **Note:** `kubectl get` and `kubectl describe` commands don't show secret contents by default to protect sensitive data.

**Output:**
```bash
Name:            db-user-pass
Namespace:       default
Labels:          <none>
Annotations:     <none>

Type:            Opaque

Data
====
password.txt:    12 bytes
username.txt:    5 bytes
```

---

### Creating Secrets Manually

You can create Secrets using YAML or JSON manifests. The Secret object has two fields: `data` (base64-encoded) and `stringData` (plain text, automatically encoded).

#### Encode Values to Base64

```bash
echo -n 'admin' | base64
# Output: YWRtaW4=

echo -n '1f2d1e2e67df' | base64
# Output: MWYyZDFlMmU2N2Rm
```

#### Decode Base64 Values

```bash
echo 'YWRtaW4=' | base64 -d
# Output: admin
```

> **Important:** The `-n` flag is crucial to avoid including a trailing newline in the base64 encoding.

#### Create Secret YAML File

Create `secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  username: YWRtaW4=              # base64 encoded 'admin'
  password: MWYyZDFlMmU2N2Rm      # base64 encoded '1f2d1e2e67df'
# Alternative using stringData (automatically encoded):
# stringData:
#   username: admin
#   password: '1f2d1e2e67df'
```

**Reference:** [Kubernetes Secret API Documentation](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/secret-v1/)

#### Apply the Secret

```bash
kubectl apply -f ./secret.yaml
```

**Output:**
```bash
secret/mysecret created
```

---

### Decoding a Secret

Retrieve and view secrets:

```bash
kubectl get secret mysecret -o yaml
```

**Output:**
```yaml
apiVersion: v1
data:
  password: MWYyZDFlMmU2N2Rm
  username: YWRtaW4=
kind: Secret
metadata:
  name: mysecret
  namespace: default
type: Opaque
```

#### Decode Password Field

```bash
echo 'MWYyZDFlMmU2N2Rm' | base64 --decode
# Output: 1f2d1e2e67df
```

---

### Using Secrets in Pods

#### Method 1: Plain Environment Variables (Not Recommended)

Create `mysecret-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-pod
spec:
  containers:
  - name: mycontainer
    image: redis
    env:
      - name: SECRET_USERNAME
        value: admin
      - name: SECRET_PASSWORD
        value: 1f2d1e2e67df
  restartPolicy: Never
```

Create and test the pod:

```bash
kubectl apply -f mysecret-pod.yaml
kubectl exec -it secret-env-pod -- bash
echo $SECRET_USERNAME
echo $SECRET_PASSWORD
exit
```

Delete the pod:

```bash
kubectl delete -f mysecret-pod.yaml
```

#### Method 2: Environment Variables from Secrets (Recommended)

Update `mysecret-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-pod
spec:
  containers:
  - name: mycontainer
    image: redis
    env:
      - name: SECRET_USERNAME
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: username
      - name: SECRET_PASSWORD
        valueFrom:
          secretKeyRef:
            name: mysecret
            key: password
  restartPolicy: Never
```

Apply the updated pod:

```bash
kubectl apply -f mysecret-pod.yaml
```

### Consuming Secret Values from Environment Variables

Inside the container, secret keys appear as normal environment variables with base64-decoded values:

```bash
kubectl exec -it secret-env-pod -- bash
echo $SECRET_USERNAME    # Output: admin
echo $SECRET_PASSWORD    # Output: 1f2d1e2e67df
env                      # View all environment variables
exit
```

---

## Part 3 - ConfigMaps in Kubernetes

### What is a ConfigMap?

ConfigMaps allow you to decouple configuration from container images, making applications more portable. Unlike Secrets, ConfigMaps are designed for non-sensitive configuration data.

### Creating ConfigMaps

#### Method 1: From Literal Values

```bash
kubectl create configmap demo-config --from-literal=greeting=Hola
```

#### Method 2: From a YAML File

Create `configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-config
data:
  greeting: Hola
```

Apply the ConfigMap:

```bash
kubectl apply -f configmap.yaml
```

### Verify ConfigMap

```bash
kubectl get configmap
kubectl describe configmap demo-config
kubectl get configmap demo-config -o yaml
```

---

### Using ConfigMaps in Applications

#### Application Setup

Create a directory structure:

```bash
mkdir k8s
cd k8s
```

#### Create Deployment

Create `k8s/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
        - name: demo
          image: ondiacademy/demo:hello-config-env
          ports:
            - containerPort: 8888
          env:
            - name: GREETING
              valueFrom:
                configMapKeyRef:
                  name: demo-config
                  key: greeting
```

#### Create Service

Create `k8s/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-service
spec:
  type: NodePort
  selector:
    app: demo
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8888
      nodePort: 30001
```

#### Deploy and Test

```bash
kubectl apply -f k8s/

kubectl get svc
# Output:
# NAME           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
# demo-service   NodePort    10.102.145.186   <none>        80:30001/TCP   5s

curl <worker-ip>:30001
# Output: Hola, Clarusway!
```

#### Clean Up

```bash
kubectl delete -f k8s
```

---

### Using All ConfigMap Keys as Environment Variables

Instead of mapping individual keys, you can inject all ConfigMap data at once using `envFrom`.

#### Update ConfigMap

Modify `configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-config
data:
  GREETING: Hallo
  VAR1: value1
  var2: value2
```

#### Update Deployment

Modify `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
        - name: demo
          image: ondiacademy/demo:hello-config-env
          ports:
            - containerPort: 8888
          envFrom:
          - configMapRef:
              name: demo-config
```

> **Key Change:** Using `envFrom` instead of `env` injects all ConfigMap keys as environment variables.

#### Apply and Test

```bash
kubectl apply -f k8s/

kubectl get svc
curl <worker-ip>:30001
# Output: Hallo, Clarusway!
```

#### Verify Environment Variables

```bash
kubectl get po
kubectl exec -it <pod-name> -- sh
env
exit
```

All ConfigMap keys are now available as environment variables inside the container.

```bash
kubectl delete -f k8s
```

---

### ConfigMaps from Files

#### Create Content File

```bash
echo "Welcome to the Kubernetes Lessons." > content
```

#### Create ConfigMap from File

```bash
kubectl create configmap nginx-config --from-file=./content
```

#### View ConfigMap

```bash
kubectl get configmap/nginx-config -o yaml
```

**Output:**
```yaml
apiVersion: v1
data:
  content: Welcome to the Kubernetes Lessons.
kind: ConfigMap
metadata:
  name: nginx-config
  namespace: default
```

---

### Using ConfigMaps as Volumes

Volumes are a common way to mount configuration files inside containers.

#### Create Nginx Deployment

Create `nginx-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 1
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
          image: nginx:latest
          ports:
            - containerPort: 80
          volumeMounts:
          - mountPath: /usr/share/nginx/html/
            name: nginx-config-volume
            readOnly: true
      volumes:
      - name: nginx-config-volume
        configMap:
          name: nginx-config
          items:
          - key: content
            path: index.html
```

This configuration:
- Selects the `content` key from `nginx-config` ConfigMap
- Mounts it inside the container at `/usr/share/nginx/html/`
- Names the file `index.html`

Apply the deployment:

```bash
kubectl apply -f nginx-deployment.yaml
```

#### Create Nginx Service

Create `nginx-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  labels:
    app: nginx
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30002
  selector:
    app: nginx
```

Apply the service:

```bash
kubectl apply -f nginx-service.yaml
```

#### Test the Application

```bash
curl <worker-ip>:30002
# Output: Welcome to the Kubernetes Lessons.
```

#### Clean Up

```bash
kubectl delete -f nginx-service.yaml
kubectl delete -f nginx-deployment.yaml
```

---

### Optional: Using Secrets as Volumes

#### Create Secret

```bash
kubectl create secret generic nginx-secret \
  --from-literal=username=devuser \
  --from-literal=password='devpassword'
```

#### View Secret

```bash
kubectl get secret nginx-secret -o yaml
```

#### Update Nginx Deployment with Secret Volume

Update `nginx-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 1
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
          image: nginx:latest
          ports:
            - containerPort: 80
          volumeMounts:
          - mountPath: /usr/share/nginx/html/
            name: nginx-config-volume
            readOnly: true
          - mountPath: /test
            name: secret-volume
      volumes:
      - name: nginx-config-volume
        configMap:
          name: nginx-config
          items:
          - key: content
            path: index.html
      - name: secret-volume
        secret:
          secretName: nginx-secret
```

Apply the changes:

```bash
kubectl apply -f nginx-deployment.yaml
```

#### Verify Secret Files

```bash
kubectl get pod
kubectl exec -it <nginx-pod-name> -- bash
cd /test
ls              # Shows: password  username
cat password    # Shows: devpassword
cat username    # Shows: devuser
exit
```

> **Note:** File names in the `/test` folder are the keys from the `nginx-secret`, and the file contents are the corresponding values.

---

## Challenge (Optional)

Use the Hello app from the Clarusway repository and configure the `$GREETINGS` environment variable using Secrets instead of ConfigMaps.

---

## Additional Resources

### Kubernetes Documentation

- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Kubernetes ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secret Types](https://kubernetes.io/docs/concepts/configuration/secret/#secret-types)
- [kubectl Commands Reference](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands)

### Best Practices

- Always use Secrets for sensitive data (passwords, tokens, keys)
- Use ConfigMaps for non-sensitive configuration
- Never commit secrets to version control
- Consider using external secret management tools for production (e.g., HashiCorp Vault, AWS Secrets Manager)
- Regularly rotate secrets
- Use RBAC to control access to secrets
