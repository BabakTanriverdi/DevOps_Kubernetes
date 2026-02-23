# Hands-on Kubernetes-02 : Kubernetes Temel İşlemler

Bu uygulamalı eğitimin amacı, öğrencilere bir Kubernetes cluster'ında temel işlemler hakkında bilgi vermektir.

## Öğrenim Hedefleri

Bu uygulamalı eğitimin sonunda öğrenciler;

- Kubernetes'te node'lar, pod'lar, deployment'lar ve replicaset'lerin temel işlemlerini öğrenecekler

- Kubernetes'te deployment'ları güncelleme ve geri alma işlemlerini öğrenecekler

- Kubernetes'te namespace kullanımlarını öğrenecekler

## İçindekiler

- Bölüm 1 - Kubernetes Cluster Kurulumu

- Bölüm 2 - Kubernetes'te Temel İşlemler

- Bölüm 3 - Kubernetes'te Namespace'ler

- Bölüm 4 - Deployment Rolling Update ve Rollback İşlemleri


## Bölüm 1 - Kubernetes Cluster Kurulumu

- [Cloudformation Template to Create Kubernetes Cluster](./cfn-template-to-create-k8s-cluster.yml) kullanarak Ubuntu 22.04 üzerinde iki node'lu (bir master, bir worker) bir Kubernetes Cluster başlatın. *Not: Master node çalışmaya başladığında, worker node otomatik olarak cluster'a katılır.*

>*Not: Kubernetes cluster ile ilgili bir sorun yaşarsanız, ders için bu linki kullanabilirsiniz.*
>https://killercoda.com/playgrounds

- Kubernetes'in çalışıp çalışmadığını ve node'ların hazır olup olmadığını kontrol edin.

```bash
kubectl cluster-info
kubectl get node
```

## Bölüm 2 - Kubernetes'te Temel İşlemler

- Desteklenen API resource'larının isimlerini ve kısa isimlerini aşağıdaki örnekte gösterildiği gibi gösterin:

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

- kubectl komutlarını görüntülemek için:

```bash
kubectl help
```

- `Nodes` ve alanlarının dokümantasyonunu alın.

```bash
kubectl explain nodes
```

- Cluster'daki node'ları görüntüleyin.

```bash
kubectl get nodes
```

### pods

- `Pods` ve alanlarının dokümantasyonunu alın.

```bash
kubectl explain pods
```
  
- `mypod.yaml` adında bir YAML dosyası oluşturun ve alanlarını açıklayın.

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

- `kubectl create` komutu ile bir pod oluşturun.

```bash
kubectl create -f mypod.yaml
```

- Pod'ları listeleyin.

```bash
kubectl get pods
```

- Pod'ları daha fazla bilgi (node ismi gibi) ile birlikte `ps output format`'ta listeleyin.
  
```bash
kubectl get pods -o wide
```

- Pod'un detaylarını gösterin.

```bash
kubectl describe pods/nginx-pod
```

- Pod'un detaylarını `yaml format`'ta gösterin.
  
```bash
kubectl get pods/nginx-pod -o yaml
```

- Pod'u silin.

```bash
kubectl delete -f mypod.yaml
# veya
kubectl delete pod nginx-pod
```

### ReplicaSets

- `replicasets` ve alanlarının dokümantasyonunu alın.

```bash
kubectl explain replicaset
```

- `myreplicaset.yaml` adında bir YAML dosyası oluşturun ve alanlarını açıklayın.

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
  labels:
    environment: dev
spec:
  # durumunuza göre replica sayısını değiştirin
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

- `kubectl apply` komutu ile replicaset'i oluşturun.

```bash
kubectl apply -f myreplicaset.yaml
```

- ReplicaSet'leri listeleyin.

```bash
kubectl get replicaset
```

- Pod'ları daha fazla bilgi ile listeleyin.
  
```bash
kubectl get pods -o wide
```

- ReplicaSet'lerin detaylarını gösterin.

```bash
kubectl describe replicaset nginx-rs
```

- ReplicaSet'leri silin (Not: Bir ReplicaSet'i sildiğinizde, onun yönettiği tüm Pod'lar da silinir).

```bash
kubectl delete replicaset nginx-rs
```

#### Pod Selector

.spec.selector alanı bir label selector'dır. 

.spec.selector alanı ve .spec.template.metadata alanı aynı olmalıdır. Bu konuyla ilgili loose coupling gibi ek konular vardır, ancak bunları service object'inde tartışıyoruz.

### Deployments

- `Deployments` ve alanlarının dokümantasyonunu alın.

```bash
kubectl explain deployments
```

- `mydeployment.yaml` adında bir YAML dosyası oluşturun ve alanlarını açıklayın.

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

- `kubectl apply` komutu ile deployment'ı oluşturun.
  
```bash
kubectl apply -f mydeployment.yaml
```

- Deployment'ları listeleyin.

```bash
kubectl get deployments
```

- Pod'ları daha fazla bilgi ile listeleyin.
  
```bash
kubectl get pods -o wide
```

- Deployment'ların detaylarını gösterin.

```bash
kubectl describe deploy/nginx-deployment
```

- Bir pod içindeki container için log'ları yazdırın.

```bash
kubectl logs <pod-name>
```

- Eğer multi-container pod varsa, bir container'ın log'larını yazdırabiliriz.

```bash
kubectl logs <pod-name> -c <container-name>
```

- Container içinde bir komut çalıştırın.

```bash
kubectl exec <pod-name> -- date
```

```bash
kubectl exec <pod-name> -- cat /usr/share/nginx/html/index.html
```

- Container içinde bir bash shell açın.

```bash
kubectl exec -it <pod-name> -- bash
```

- ReplicaSet'leri listeleyin.

```bash
kubectl get rs
```

- ReplicaSet'lerin detaylarını gösterin.

```bash
kubectl describe rs <rs-name>
```

- Deployment'ı beş replica'ya scale edin.

```bash
kubectl scale deploy nginx-deployment --replicas=5
```

- Ama her seferinde scale için bu komutları uygulamak zorunda mıyız? Hayır, çünkü YAML dosyamız olacak ve scale ihtiyacımız olduğunda onu değiştirebiliriz.

>> mydeployment.yaml değişikliğini uyguladığınızda nasıl farklılık gösterdiğini gösterin.

- Bir pod'u silin ve yeni pod'un hemen oluşturulduğunu gösterin.

```bash
kubectl delete pod <pod-name>
kubectl get pods
```

- Deployment'ları silin.

```bash
kubectl delete deploy nginx-deployment
```

## Bölüm 3 - Kubernetes'te Namespace'ler

- Cluster'daki mevcut namespace'leri listeleyin ve açıklayın. *Kubernetes, aynı fiziksel cluster tarafından desteklenen birden fazla sanal cluster'ı destekler. Bu sanal cluster'lara `namespace` denir.*

```bash
kubectl get namespace
NAME              STATUS   AGE
default           Active   118m
kube-node-lease   Active   118m
kube-public       Active   118m
kube-system       Active   118m
```

>### default
>Kubernetes bu namespace'i içerir, böylece önce bir namespace oluşturmadan yeni cluster'ınızı kullanmaya başlayabilirsiniz.

>### kube-system
>Kubernetes sistem tarafından oluşturulan object'ler için namespace.

>### kube-public
>Bu namespace tüm client'lar (authenticate olmamış olanlar dahil) tarafından okunabilir. Bu namespace çoğunlukla cluster kullanımı için ayrılmıştır, bazı resource'ların tüm cluster genelinde görünür ve herkese açık olarak okunabilir olması gereken durumlarda. Bu namespace'in public yönü sadece bir convention'dır, bir gereklilik değildir.

>### kube-node-lease
>Bu namespace, her node ile ilişkili Lease object'lerini tutar. Node lease'leri, kubelet'in heartbeat göndermesine izin verir, böylece control plane node başarısızlığını tespit edebilir.

- Aşağıdaki içerikle `my-namespace.yaml` adında yeni bir YAML dosyası oluşturun.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mynamespace
```

- `my-namespace.yaml` dosyasını kullanarak bir namespace oluşturun.

```bash
kubectl apply -f ./my-namespace.yaml
```

- Alternatif olarak, aşağıdaki imperative komutu kullanarak bir namespace oluşturabilirsiniz (hızlı test için kullanışlıdır):

```bash
kubectl create namespace <namespace-name>
```

- Her namespace'te pod'lar oluşturun.

```bash
kubectl create deployment mynginx --image=nginx
kubectl create deployment myapache --image=httpd -n=mynamespace
```

- `default` namespace'teki deployment'ları listeleyin.

```bash
kubectl get deployment
```

- `mynamespace`'teki deployment'ları listeleyin.

```bash
kubectl get deployment -n mynamespace
```

- Tüm deployment'ları listeleyin.

```bash
kubectl get deployment -o wide --all-namespaces
```

- Namespace'i silin (Not: Bu, o namespace içindeki tüm resource'ları da silecektir).

```bash
kubectl delete namespaces mynamespace
```
- Namespace ve Deployment'ı tek bir YAML dosyasında birlikte oluşturabilirsiniz.

- `namespace-and-deployment.yaml` adında bir YAML dosyası oluşturun ve aşağıdaki içeriği ekleyin.
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


- Manifest'i uygulayın.

```bash
kubectl apply -f namespace-and-deployment.yaml
```

- Namespace ve resource'ları doğrulayın.

```bash
kubectl get ns
kubectl get deploy -n mynamespace
kubectl get rs -n mynamespace
kubectl get pods -n mynamespace -o wide
kubectl get deploy,rs,pod -n mynamespace -o wide
# opsiyonel (namespace'deki her şeyi gösterir)
kubectl get all -n mynamespace
```

- Bu manifest ile oluşturulan resource'ları silin (temizleme).

```bash
kubectl delete -f namespace-and-deployment.yaml
# veya manuel olarak silin
kubectl delete deploy nginx-deployment -n mynamespace
kubectl delete ns mynamespace
```

## Bölüm 4 - Kubernetes'te Deployment Rolling Update ve Rollback

- Yeni bir klasör oluşturun ve adını deployment-lesson koyun.

```bash
mkdir deployment-lesson
cd deployment-lesson
```

- Bir `mydeploy.yaml` oluşturun ve aşağıdaki metni girin. Image version'ının 1.0 olduğuna dikkat edin.

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
  minReadySeconds: 10  # Pod'un hazır kabul edilmeden önce 10 saniye bekle (hatalı rollout'ları önlemeye yardımcı olur)
  strategy:
    type: RollingUpdate  # Pod'ları aynı anda değil, kademeli olarak güncelle
    rollingUpdate:
      maxUnavailable: 1  # Update sırasında kullanılamaz olabilecek maksimum pod sayısı
      maxSurge: 1        # İstenen replica sayısının üzerinde oluşturulabilecek maksimum pod sayısı
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

- `kubectl apply` komutu ile deployment'ı oluşturun.

```bash
kubectl apply -f mydeploy.yaml
```

- Label kullanarak `mydeploy` deployment'ının `Deployment`, `ReplicaSet` ve `Pods`'larını listeleyin ve ReplicaSet'in adını not edin.

```bash
kubectl get deploy,rs,po -l app=myapp
```

- Deployment'ı açıklayın ve deployment'ın image'ını not edin. Bizim durumumuzda, `ondiacademy/ondiaweb:1.0`.

```bash
kubectl describe deploy mydeploy
```

- Önceki rollout revision'larını görüntüleyin.

```bash
kubectl rollout history deploy mydeploy
```

- Revision numarası ile detayları görüntüleyin, bizim durumumuzda 1. Ve image'ın adını not edin.

```bash
kubectl rollout history deploy mydeploy --revision=1
```

- Image'ı 2.0 versiyonuna yükseltin.

```bash
kubectl set image deploy mydeploy mycontainer=ondiacademy/ondiaweb:2.0
kubectl annotate deploy mydeploy kubernetes.io/change-cause="deploy/mydeploy is set as mycontainer=ondiacademy/ondiaweb:2.0"
```

- Rollout durumunu izleyin (opsiyonel ama kullanışlıdır).

```bash
kubectl rollout status deploy mydeploy
```

- Rollout geçmişini gösterin.

```bash
kubectl rollout history deploy mydeploy
```

- Revision'lar hakkında detayları görüntüleyin.

```bash
kubectl rollout history deploy mydeploy --revision=1
kubectl rollout history deploy mydeploy --revision=2
```

- Label kullanarak `mydeploy` deployment'ının `Deployment`, `ReplicaSet` ve `Pods`'larını listeleyin ve ReplicaSet'leri açıklayın.

```bash
kubectl get deploy,rs,po -l app=myapp
```

- kubectl edit komutları ile image'ı 3.0 versiyonuna yükseltin.

```bash
kubectl edit deploy/mydeploy
```

- Aşağıdaki gibi bir çıktı göreceğiz.

```yaml
# Lütfen aşağıdaki object'i düzenleyin. '#' ile başlayan satırlar göz ardı edilecek,
# ve boş bir dosya düzenlemeyi iptal edecektir. Bu dosya kaydedilirken bir hata oluşursa
# ilgili hatalarla yeniden açılacaktır.
#
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "2"
    kubectl.kubernetes.io/last-applied-configuration: |
    ...
```

- `metadata.annotations.kubernetes.io/change-cause` ve `spec.template.spec.containers.image` alanlarını aşağıdaki gibi değiştirin.

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

- Rollout geçmişini gösterin.

```bash
kubectl rollout history deploy mydeploy
```

- Revision'lar hakkında detayları görüntüleyin.

```bash
kubectl rollout history deploy mydeploy --revision=1
kubectl rollout history deploy mydeploy --revision=2
kubectl rollout history deploy mydeploy --revision=3
```

- `kubectl get rs` uygulayın ve kaç tane replica set olduğunu gösterin ve nedenini açıklayın (Kubernetes, rollback amaçları için eski ReplicaSet'leri tutar).

```bash
kubectl get rs
```

- Label kullanarak `mydeploy` deployment'ının `Deployment`, `ReplicaSet` ve `Pods`'larını listeleyin ve ReplicaSet'leri açıklayın.

```bash
kubectl get deploy,rs,po -l app=myapp
```

- `revision 1`'e geri dönün (rollback yapın).

```bash
kubectl rollout undo deploy mydeploy --to-revision=1
```

- Rollout geçmişini gösterin ve 2, 3 ve 4 revision'larına sahip olduğumuzu gösterin. Orijinal revision olan `revision 1`'in `revision 4` olduğunu açıklayın.

```bash
kubectl rollout history deploy mydeploy
kubectl rollout history deploy mydeploy --revision=2
kubectl rollout history deploy mydeploy --revision=3
kubectl rollout history deploy mydeploy --revision=4
```

- Artık mevcut olmayan `revision 1`'i çekmeyi deneyin.

```bash
kubectl rollout history deploy mydeploy --revision=1
```

- Label kullanarak `mydeploy` deployment'ının `Deployment`, `ReplicaSet` ve `Pods`'larını listeleyin ve orijinal ReplicaSet'in **ikiye** (deployment spec'imizde tanımlandığı gibi) scale edildiğini ve daha yeni ReplicaSet'lerin sıfıra scale edildiğini açıklayın.

```bash
kubectl get deploy,rs,po -l app=myapp
```

- Deployment'ı silin.

```bash
kubectl delete deploy -l app=myapp
```

## Ek Notlar

### Rolling Update Strategy Parametreleri Açıklaması

- **minReadySeconds**: Bir pod'un kullanılabilir kabul edilmeden önce hazır olması gereken minimum süre. Bu, hatalı deployment'ların çok hızlı rollout olmasını önlemeye yardımcı olur.

- **maxUnavailable**: Update işlemi sırasında kullanılamaz olabilecek maksimum pod sayısı. Bunu 1'e ayarlamak, en az 1 pod'un her zaman çalışır durumda olacağı anlamına gelir.

- **maxSurge**: Update sırasında istenen replica sayısının üzerinde oluşturulabilecek maksimum pod sayısı. Bunu 1'e ayarlamak, Kubernetes'in rollout sırasında geçici olarak 3 pod'a (2 istenen + 1 surge) sahip olmasına izin verir.

### Neden Birden Fazla ReplicaSet Var

Kubernetes, hızlı rollback'leri etkinleştirmek için eski ReplicaSet'leri (0'a scale edilmiş) tutar. Rollback yaptığınızda, image'ları tekrar çekmek yerine eski ReplicaSet'i basitçe scale eder. Bu, her şeyi sıfırdan yeniden oluşturmaktan daha verimlidir.