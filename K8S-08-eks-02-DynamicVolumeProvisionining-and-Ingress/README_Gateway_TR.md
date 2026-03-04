# Hands-on EKS-02: Gateway API ve Dynamic Volume Provisioning

Bu hands-on eğitiminin amacı öğrencilere Dynamic Volume Provisioning ve Gateway API konularında bilgi kazandırmaktır.

> ⚠️ **Neden Gateway API?**
> Kubernetes, Ingress kaynağını artık aktif olarak geliştirmeyi durdurmaktadır. Resmi öneri artık **Gateway API** kullanmaktır. Gateway API; Ingress'e kıyasla çok daha esnek, güçlü ve standart bir trafik yönetimi sunar.

## Öğrenme Hedefleri

Bu hands-on eğitiminin sonunda öğrenciler;

- eksctl ile EKS Cluster oluşturmayı ve yönetmeyi öğrenecek.

- Kalıcı veri yönetimi ihtiyacını açıklayabilecek.

- PersistentVolume ve PersistentVolumeClaim kullanabilecek.

- Gateway API ve Gateway Controller kullanımını anlayabilecek.

## İçerik

- Part 1 - Amazon Linux 2023 üzerine kubectl ve eksctl kurulumu

- Part 2 - EKS üzerinde Kubernetes Cluster oluşturma

- Part 3 - Gateway API

- Part 4 - Dynamic Volume Provisioning


## Ön Gereksinimler

1. AWS CLI kurulu ve yapılandırılmış

2. kubectl kurulu

3. eksctl kurulu

eksctl kurulumu veya güncellenmesi hakkında bilgi için bkz. [eksctl kurulum rehberi.](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html#installing-eksctl)

## Part 1 - Amazon Linux 2023 üzerine kubectl ve eksctl Kurulumu

### kubectl Kurulumu

- SSH erişimine izin veren güvenlik grubuyla Amazon Linux 2023 AMI'li bir AWS EC2 instance'ı başlat.

- Instance'a SSH ile bağlan.

- Kurulu paketleri ve paket önbelleğini güncelle.

```bash
sudo dnf update -y
```

- Amazon EKS tarafından sağlanan kubectl binary'sini indir.

```bash
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.34.1/2025-09-19/bin/linux/amd64/kubectl
```

- Binary'ye çalıştırma izni ver.

```bash
chmod +x ./kubectl
```

- Binary'yi PATH'indeki bir klasöre kopyala. Daha önce kubectl kurduysanız $HOME/bin/kubectl oluşturmanızı ve $HOME/bin'in $PATH'inizde önce gelmesini sağlamanızı öneririz.

```bash
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
```

- (İsteğe bağlı) Shell başlatma dosyasına $HOME/bin yolunu ekle; böylece her shell açıldığında otomatik yapılandırılır.

```bash
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
```

- kubectl kurulduktan sonra sürümünü şu komutla doğrulayabilirsin:

```bash
kubectl version --client
```

### eksctl Kurulumu

- eksctl'nin en son sürümünü aşağıdaki komutla indir ve çıkart.

```bash
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
```

- Binary'yi /tmp klasörüne taşı ve çıkart.

```bash
tar -xzf eksctl_$(uname -s)_amd64.tar.gz -C /tmp && rm eksctl_$(uname -s)_amd64.tar.gz
```

- Çıkarılan binary'yi /usr/local/bin'e taşı.

```bash
sudo mv /tmp/eksctl /usr/local/bin
```

- Kurulumun başarılı olduğunu şu komutla doğrula.

```bash
eksctl version
```

## Part 2 - EKS üzerinde Kubernetes Cluster Oluşturma

- AWS kimlik bilgilerini yapılandır. Ya da EC2 instance'ına `AWS IAM Role` ekleyebilirsin.

```bash
aws configure
```

- `eksctl` ile EKS cluster'ı oluştur. Bu işlem biraz zaman alacaktır.

```bash
eksctl create cluster --region us-east-1 --version 1.34 --zones us-east-1a,us-east-1b,us-east-1c --node-type t3a.medium --nodes 2 --nodes-min 2 --nodes-max 3 --name cw-cluster
```

### Alternatif yol (Worker node'a SSH bağlantısı dahil)

- Gerekirse `ssh-keygen -f ~/.ssh/id_rsa` komutuyla bir SSH anahtarı oluştur.

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

- Varsayılan değerleri açıkla.

```bash
eksctl create cluster --help
```

- AWS Management Console'da `eks service`'i göster ve `cloudformation service`'deki `eksctl-my-cluster-cluster` stack'ini açıkla.


## Part 3 - Gateway API

- Bir klasör oluştur ve adını gateway-lesson koy.

```bash
mkdir gateway-lesson
cd gateway-lesson
```

- clarusshop deployment objesi için `clarusshop.yaml` adlı bir dosya oluştur.

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

- clarusshop service objesi için `clarusshop-svc.yaml` adlı bir dosya oluştur.

> ⚠️ Gateway API kullanırken servis tipi `ClusterIP` olmalıdır. `NodePort` gerekmez.

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

- account deployment objesi için `account.yaml` adlı bir dosya oluştur.

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

- account service objesi için `account-svc.yaml` adlı bir dosya oluştur.

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

- Objeleri oluştur.

```bash
kubectl apply -f .
```

### Gateway API

- Gateway API ve Gateway Controller'ı kısaca açıkla. Ek bilgi için şu kaynaklara bakılabilir:

  - https://gateway-api.sigs.k8s.io/
  - https://docs.nginx.com/nginx-gateway-fabric/

- Gateway API üç temel kaynaktan oluşur:

| Kaynak | Görevi |
|---|---|
| `GatewayClass` | Hangi controller'ın kullanılacağını tanımlar (nginx, istio vb.) |
| `Gateway` | Dışarıdan gelen trafiği dinleyen "kapı" — port ve protokol tanımlar |
| `HTTPRoute` | Gelen isteğin hangi servise yönlendirileceğini belirler |

- Gateway API CRD'lerini kur. CRD manifest dosyaları standart apply için çok büyük olduğundan `--server-side=true` flag'i gereklidir.

```bash
kubectl apply --server-side=true -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
```

- NGINX Gateway Fabric controller'ı kur.

```bash
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v2.4.2/deploy/crds.yaml
kubectl apply -f https://raw.githubusercontent.com/nginxinc/nginx-gateway-fabric/v2.4.2/deploy/default/deploy.yaml
```

- Controller'ın çalıştığını doğrula.

```bash
kubectl get pods -n nginx-gateway
kubectl get gatewayclass
```

- Gateway objesi için `gateway.yaml` adlı bir dosya oluştur.

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

- Gateway objesini oluştur.

```bash
kubectl apply -f gateway.yaml
kubectl get gateway
```

- HTTPRoute objesi için `httproute.yaml` adlı bir dosya oluştur.

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

- HTTPRoute objesini oluştur.

```bash
kubectl apply -f httproute.yaml
kubectl get httproute
```

- Dış adresi almak için Gateway'i kontrol et.

```bash
kubectl get gateway clarusshop-gateway
```

- Aşağıdaki gibi bir çıktı alacaksın.

```bash
NAME                  CLASS   ADDRESS                                                                    READY   AGE
clarusshop-gateway    nginx   afdfe2adcb6934b4abb645258b8f73d2-501976fbe439549f.elb.us-east-1.amazonaws.com   True    12s
```

- Servislere ulaşmak için adresi kullan.

```bash
curl afdfe2adcb6934b4abb645258b8f73d2-501976fbe439549f.elb.us-east-1.amazonaws.com
curl afdfe2adcb6934b4abb645258b8f73d2-501976fbe439549f.elb.us-east-1.amazonaws.com/account
```

- Her şeyi sil.

```bash
kubectl delete -f .
```

#### Host Tanımlama

- HTTPRoute'a bir hostname tanımlayabiliriz. `httproute.yaml` dosyasını aşağıdaki gibi güncelle.

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

- HTTPRoute objesini uygula.

```bash
kubectl apply -f httproute.yaml
kubectl get httproute
```

- Uygulamaya `host` adıyla ulaşmak için `route53` servisinde adres (network load balancer) için `clarusshop.clarusway.us` kaydı oluştur.

- Tüm dosyaları uygula.

```bash
kubectl apply -f .
```

- Uygulamaya curl komutuyla ulaşabilirsin.

```bash
curl clarusshop.clarusway.us
curl clarusshop.clarusway.us/account
```

- Tüm objeleri sil.

```bash
kubectl delete -f .
```

#### İsme Dayalı Sanal Hosting

- `virtual-hosting` adlı bir klasör oluştur.

```bash
mkdir virtual-hosting && cd virtual-hosting
```

- nginx ve Apache için iki pod ve servis oluştur.

```bash
kubectl run mynginx --image=nginx --port=80 --expose
kubectl run myapache --image=httpd --port=80 --expose
kubectl get po,svc
```

- `virtual-gateway.yaml` adlı bir Gateway dosyası oluştur.

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

- nginx için `nginx-route.yaml` adlı bir HTTPRoute dosyası oluştur.

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

- Apache için `apache-route.yaml` adlı bir HTTPRoute dosyası oluştur.

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

- Tüm objeleri oluştur.

```bash
kubectl apply -f .
kubectl get gateway,httproute
```

- Aşağıdaki gibi bir çıktı alacaksın.

```bash
NAME                                        CLASS   ADDRESS                                                                    READY   AGE
gateway.gateway.networking.k8s.io/virtual-gateway   nginx   afdfe2adcb6934b4abb645258b8f73d2-501976fbe439549f.elb.us-east-1.amazonaws.com   True    6s

NAME                                              HOSTNAMES                 AGE
httproute.gateway.networking.k8s.io/nginx-route   ["nginx.clarusway.us"]    6s
httproute.gateway.networking.k8s.io/apache-route  ["apache.clarusway.us"]   6s
```

- Uygulamaya `host` adıyla ulaşmak için `route53` servisinde adres (network load balancer) için `nginx.clarusway.us` ve `apache.clarusway.us` kayıtlarını oluştur.

- Host adresini kontrol et.

```bash
curl nginx.clarusway.us
curl apache.clarusway.us
```

- Tüm objeleri sil.

```bash
kubectl delete -f .
```

## Part 4 - Dynamic Volume Provisioning

### Amazon Elastic Block Store (Amazon EBS) Container Storage Interface (CSI) Sürücüsü

- Amazon Elastic Block Store (Amazon EBS) Container Storage Interface (CSI) sürücüsü, Amazon Elastic Kubernetes Service (Amazon EKS) cluster'larının kalıcı volume'ler için Amazon EBS volume'lerinin yaşam döngüsünü yönetmesine olanak tanır.

- Amazon EBS CSI sürücüsü, cluster ilk oluşturulduğunda kurulu gelmez. Sürücüyü kullanmak için Amazon EKS eklentisi veya kendi yönettiğin bir eklenti olarak eklemelisin.

- Amazon EBS CSI sürücüsünü kur. Amazon EKS eklentisi olarak nasıl ekleneceğine ilişkin talimatlar için bkz. [Amazon EBS CSI sürücüsünü Amazon EKS eklentisi olarak yönetme](https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html).

### Cluster'ın için IAM OIDC Provider Oluşturma

- AWS EBS CSI kullanmak için cluster'ın için bir AWS Identity and Access Management (IAM) OpenID Connect (OIDC) provider'ı olması gerekir.

- Cluster'ın için mevcut bir IAM OIDC provider'ı olup olmadığını belirle. Cluster'ının OIDC provider ID'sini al ve bir değişkende sakla.

```bash
oidc_id=$(aws eks describe-cluster --name cw-cluster --query "cluster.identity.oidc.issuer" --output text | cut -d '/' -f 5)
```

- Hesabında cluster'ının ID'siyle eşleşen bir IAM OIDC provider'ı olup olmadığını kontrol et.

```bash
aws iam list-open-id-connect-providers | grep $oidc_id
```
Önceki komuttan çıktı geliyorsa cluster'ın için zaten bir provider var demektir ve sonraki adımı atlayabilirsin. Çıktı gelmiyorsa cluster'ın için bir IAM OIDC provider oluşturman gerekir.

- Aşağıdaki komutla cluster'ın için bir IAM OIDC identity provider oluştur. my-cluster yerine kendi değerini yaz.

```bash
eksctl utils associate-iam-oidc-provider --region=us-east-1 --cluster=cw-cluster --approve
```

### Amazon EBS CSI Sürücüsü için IAM Rolü Oluşturma

- Amazon EBS CSI eklentisi, AWS API'larına senin adına çağrı yapabilmek için IAM izinlerine ihtiyaç duyar.

- Eklenti dağıtıldığında ebs-csi-controller-sa adlı bir service account oluşturur ve bunu kullanacak şekilde yapılandırır. Bu service account, gerekli Kubernetes izinlerinin atandığı bir Kubernetes clusterrole'e bağlıdır.

#### eksctl ile Amazon EBS CSI eklentisi IAM rolü oluşturma

- Aşağıdaki komutla bir IAM rolü oluştur ve gerekli AWS yönetilen politikasını ekle. cw-cluster yerine cluster'ının adını yaz. Komut, bir IAM rolü oluşturan, IAM politikasını buna ekleyen ve mevcut ebs-csi-controller-sa service account'unu IAM rolünün Amazon Resource Name (ARN) ile açıklayan bir AWS CloudFormation stack'i dağıtır.

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

### Amazon EBS CSI Eklentisini Ekleme

#### eksctl ile Amazon EBS CSI eklentisini ekleme

- Aşağıdaki komutu çalıştır. cw-cluster yerine cluster'ının adını, 111122223333 yerine hesap ID'ni ve AmazonEKS_EBS_CSI_DriverRole yerine daha önce oluşturulan IAM rolünün adını yaz.

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
eksctl create addon --name aws-ebs-csi-driver --cluster cw-cluster --service-account-role-arn arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole --force
```

- Önce cluster'daki StorageClass objesini kontrol et.

```bash
kubectl get sc

kubectl describe sc/gp2
```

- `storage-class` adlı bir dizin oluştur ve o dizine geç.

```bash
cd && mkdir storage-class && cd storage-class
```

- Aşağıdaki ayarlarla bir StorageClass oluştur.

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

- Varsayılan storageclass'ı açıkla.

```bash
kubectl get storageclass
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp2 (default)   kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  75m
myaws-sc        ebs.csi.aws.com         Delete          WaitForFirstConsumer   false                  7s
```

- Aşağıdaki ayarlarla bir PersistentVolumeClaim oluştur ve AWS management console'da yeni volume'ün oluşturulduğunu göster.

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

- PV ve PVC'yi listele ve aralarındaki bağlantıları açıkla.

```bash
kubectl get pv,pvc
```
- Aşağıdaki gibi bir çıktı göreceksin.

```text
NAME                    STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/clarus-pv-claim   Pending                    myaws-sc       <unset>                 10s
```

- Aşağıdaki ayarlarla bir pod oluştur.

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

- Pod'a gir ve EBS'nin /usr/share/nginx/html yoluna mount edildiğini gör.

```bash
kubectl exec -it test-aws -- bash
```
- Aşağıdaki gibi bir çıktı göreceksin.

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

- Oluşturduğumuz storageclass'ı sil.

```bash
kubectl get storageclass
```
- Aşağıdaki gibi bir çıktı göreceksin.

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

- Aşağıdaki gibi bir çıktı göreceksin.

```text
NAME                    PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE     ALLOWVOLUMEEXPANSION   AGE
gp2 (default)            kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer  false                  52m
```

- Pod'u sil.

```bash
kubectl delete -f pod-with-dynamic-storage.yaml
kubectl delete -f clarus-pv-claim.yaml
```

- Cluster'ı sil.

```bash
eksctl get cluster --region us-east-1
```
- Aşağıdaki gibi bir çıktı göreceksin.

```text
NAME            REGION
cw-cluster      us-east-1
```
```bash
eksctl delete cluster cw-cluster --region us-east-1
```

- İlgili EBS volume'lerini silmeyi unutma.
