# Hands-on Kubernetes-03: Kubernetes Networking and Service Discovery

Bu uygulamalı eğitimin amacı, öğrencilere Kubernetes Services bilgisi vermektir.

## Öğrenme Kazanımları

Bu uygulamalı eğitimin sonunda öğrenciler:

- `Pods`'ları `Services` ile mantıksal olarak gruplama ve bir uygulamaya erişim sağlamanın faydalarını açıklayabilecek.

- Kubernetes'te mevcut service discovery seçeneklerini keşfedebilecek.

- Kubernetes'teki farklı Service türlerini öğrenecek.

- Kubernetes cluster'larında DNS çözümlemesinin nasıl çalıştığını anlayacak.

## İçindekiler

- Part 1 - Kubernetes Cluster'ını Kurma

- Part 2 - Kubernetes'te Services, Load Balancing ve Networking

- Part 3 - Gelişmiş Service Kavramları ve Sorun Giderme

## Part 1 - Kubernetes Cluster'ını Kurma

- Ubuntu 22.04 ile iki node'lu (bir master, bir worker) bir Kubernetes Cluster'ı başlatın. [Cloudformation Template to Create Kubernetes Cluster](../S2-kubernetes-02-basic-operations/cfn-template-to-create-k8s-cluster.yml) şablonunu kullanabilirsiniz.

> **Not:** Master node çalışmaya başladığında, worker node otomatik olarak cluster'a katılır.

> **Alternatif:** Kubernetes cluster ile ilgili sorun yaşarsanız, ders için şu linki kullanabilirsiniz:
> https://killercoda.com/playgrounds

- Kubernetes'in çalıştığını ve node'ların hazır olduğunu kontrol edin.

```bash
kubectl cluster-info
kubectl get nodes
```

**Beklenen Çıktı:**
```text
NAME           STATUS   ROLES           AGE   VERSION
kube-master    Ready    control-plane   10m   v1.28.0
kube-worker    Ready    <none>          5m    v1.28.0
```

## Part 2 - Kubernetes'te Services, Load Balancing ve Networking

Kubernetes networking dört konuyu ele alır:

- Bir Pod içindeki Container'lar loopback üzerinden iletişim kurar.

- Cluster networking, farklı Pod'lar arasında iletişim sağlar.

- Service kaynağı, Pod'larda çalışan bir uygulamayı cluster dışından erişilebilir hale getirir.

- Service'leri yalnızca cluster içinde kullanım için de yayınlayabilirsiniz.

### Service Nedir?

Bir Pod kümesi üzerinde çalışan bir uygulamayı network service olarak göstermenin soyut bir yolu.

Kubernetes ile, uygulamanızı tanıdık olmayan bir service discovery mekanizması kullanmak üzere değiştirmenize gerek yoktur.

Kubernetes, Pod'lara IP adresleri ve bir Pod kümesi için tek bir DNS adı verir ve bunlar arasında load-balance yapabilir.

### Motivasyon

Kubernetes Pod'ları ölümlüdür. Doğarlar ve öldüklerinde yeniden doğmazlar. Uygulamanızı çalıştırmak için bir Deployment kullanırsanız, Pod'ları dinamik olarak oluşturabilir ve yok edebilir.

Her Pod kendi IP adresini alır, ancak bir Deployment'ta, bir anda çalışan Pod'ların kümesi, bir dakika sonra o uygulamayı çalıştıran Pod'ların kümesinden farklı olabilir.

Bu bir soruna yol açar: Eğer bir Pod kümesi (bunlara "backend" diyelim) cluster'ınızdaki diğer Pod'lara (bunlara "frontend" diyelim) işlevsellik sağlıyorsa, frontend'ler hangi IP adresine bağlanacaklarını nasıl bulur ve takip eder ki, frontend workload'un backend kısmını kullanabilsin?

**Cevap: Services**

### Service Discovery

Temel yapı taşı, talep üzerine oluşturulabilen ve yok edilebilen bir kaynak olan Pod ile başlar. Bir Pod başka bir Node'a taşınabildiği veya yeniden zamanlanabildiği için, bu Pod'a atanan herhangi bir dahili IP zamanla değişebilir.

Bu Pod'a uygulamaya erişmek için bağlanacak olsaydık, bir sonraki yeniden dağıtımda çalışmazdı. Bir Pod'u dahili IP'lere güvenmeden harici ağlara veya cluster'lara erişilebilir hale getirmek için başka bir soyutlama katmanına ihtiyacımız var. Kubernetes bu soyutlamayı `Service` dediğimiz yapıyla sunar.

`Services`, cluster'lar arasında tek tip çalışan Pod'lara network bağlantısı sağlar. Kubernetes services, discovery ve load balancing sağlar. `Service Discovery`, bir service'e nasıl bağlanılacağını bulma işlemidir.

**Service Discovery Hakkında Önemli Noktalar:**

- Service Discovery, Container'larınızı networkleme gibidir.

- Kubernetes'teki DNS, `CoreDNS` (veya eski versiyonlarda `Kube-DNS`) tarafından yönetilen bir `Built-in Service`'tir.

- DNS Service, aynı Cluster'da çalışan diğer service'leri bulmak için Pod'lar içinde kullanılır.

- Aynı Pod içinde çalışan birden fazla container'ın DNS service'ine ihtiyacı yoktur, çünkü birbirleriyle iletişim kurabilirler.

- Aynı Pod içindeki container'lar, `localhost` üzerinde `PORT` kullanarak diğer container'lara bağlanabilir.

- DNS'in çalışması için bir Pod'un her zaman bir `Service Definition`'a ihtiyacı vardır.

- CoreDNS, arama için key-value çiftleri içeren bir veritabanıdır.

- Key'ler service'lerin adlarıdır ve value'lar bu service'lerin üzerinde çalıştığı IP adresleridir.

### Service'leri Tanımlama ve Deploy Etme

- Kubernetes'te `services`'in davranışını ve pratikte nasıl çalıştıklarını gözlemlemek için bir kurulum tanımlayalım.

- Bir klasör oluşturun ve adını service-lessons koyun.

```bash
mkdir service-lessons
cd service-lessons
```

- `web-flask.yaml` adında bir `yaml` dosyası oluşturun ve alanlarını açıklayın.

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

**Alan Açıklamaları:**
- `replicas: 3` - 3 özdeş Pod oluşturur
- `selector.matchLabels` - Deployment'a hangi Pod'ları yöneteceğini söyler
- `template.metadata.labels` - Her Pod'a atanan label'lar (selector ile eşleşmeli)
- `containerPort: 5000` - Flask uygulamasının container içinde dinlediği port

- web-flask Deployment'ı oluşturun.
  
```bash
kubectl apply -f web-flask.yaml
```

**Beklenen Çıktı:**
```text
deployment.apps/web-flask-deploy created
```

- Pod'ların detaylı bilgilerini gösterin ve IP adreslerini öğrenin:

```bash
kubectl get pods -o wide
```

- Aşağıdaki gibi bir çıktı alırız.

```text
NAME                                READY   STATUS    RESTARTS   AGE   IP           NODE          NOMINATED NODE   READINESS GATES
web-flask-deploy-5b59bc685f-2cwc2   1/1     Running   0          78s   10.244.1.5   kube-worker   <none>           <none>
web-flask-deploy-5b59bc685f-b92fr   1/1     Running   0          78s   10.244.1.4   kube-worker   <none>           <none>
web-flask-deploy-5b59bc685f-r2tb9   1/1     Running   0          78s   10.244.1.3   kube-worker   <none>           <none>
```

**Önemli:** Yukarıdaki çıktıda, her Pod için IP'ler dahili ve her instance'a özgüdür. Uygulamayı yeniden deploy edecek olsaydık, her seferinde yeni bir IP tahsis edilecekti. İşte bu yüzden Service'lere ihtiyacımız var!

Şimdi cluster içinde bir Pod'a ping atabileceğimizi kontrol edelim.

- Cluster içindeki bağlantıyı test edebilecek bir Pod oluşturmak için `forcurl.yaml` dosyası oluşturun.

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

**Not:** `imagePullPolicy: IfNotPresent`, Kubernetes'in varsa yerel olarak önbelleğe alınmış image'i kullanacağı, yoksa registry'den pull edeceği anlamına gelir.

- `forcurl` pod'unu oluşturun ve container'a giriş yapın.

```bash
kubectl apply -f forcurl.yaml
kubectl get pods
```

**Beklenen Çıktı:**
```text
NAME                                READY   STATUS    RESTARTS   AGE
forcurl                             1/1     Running   0          5s
web-flask-deploy-5b59bc685f-2cwc2   1/1     Running   0          2m
web-flask-deploy-5b59bc685f-b92fr   1/1     Running   0          2m
web-flask-deploy-5b59bc685f-r2tb9   1/1     Running   0          2m
```

- Pod'lardan birine bağlantıyı test edin:

```bash
kubectl exec -it forcurl -- sh
/ # ping 10.244.1.3
/ # curl 10.244.1.3:5000
/ # exit
```

- Pod'ların detaylı bilgilerini tekrar gösterin ve IP adreslerini öğrenin.

```bash
kubectl get pods -o wide
```

- Deployment'ı sıfıra ölçeklendirin.

```bash
kubectl scale deploy web-flask-deploy --replicas=0
```

**Beklenen Çıktı:**
```text
deployment.apps/web-flask-deploy scaled
```

- Pod'ları tekrar listeleyin ve web-flask-deploy'da pod olmadığını not edin.

```bash
kubectl get pods -o wide
```

**Beklenen Çıktı:**
```text
NAME      READY   STATUS    RESTARTS   AGE
forcurl   1/1     Running   0          2m
```

- Deployment'ı üç replica'ya ölçeklendirin.

```bash
kubectl scale deploy web-flask-deploy --replicas=3
```

- Pod'ları tekrar listeleyin ve pod'ların **farklı IP adreslerine** sahip olduğunu not edin.

```bash
kubectl get pods -o wide
```

**Gözlem:** Pod IP'leri değişti! Bu, doğrudan Pod IP'lerine güvenemeyeceğimizi gösterir.

### ClusterIP Service Oluşturma

- `Services`'in dokümantasyonunu ve alanlarını görün.

```bash
kubectl explain svc
kubectl explain svc.spec
```

- Aşağıdaki içerikle `web-svc.yaml` dosyası oluşturun ve alanlarını açıklayın.

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

**Alan Açıklamaları:**
- `type: ClusterIP` - Varsayılan tip, Service'i yalnızca cluster içinden erişilebilir yapar
- `port: 3000` - Service'in dinlediği port
- `targetPort: 5000` - Pod'daki port (Flask uygulamasının çalıştığı yer)
- `selector.app: web-flask` - Service, trafiği bu label'a sahip Pod'lara yönlendirir

**Nasıl çalışır:** Service'e port 3000'den trafik gönderdiğinizde, seçilen Pod'larda port 5000'e iletir.
  
```bash
kubectl apply -f web-svc.yaml
```

**Beklenen Çıktı:**
```text
service/web-flask-svc created
```

- Service'leri listeleyin.

```bash
kubectl get svc -o wide
```

**Beklenen Çıktı:**
```text
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE   SELECTOR
kubernetes      ClusterIP   10.96.0.1       <none>        443/TCP    4h    <none>
web-flask-svc   ClusterIP   10.98.173.110   <none>        3000/TCP   28m   app=web-flask
```

- `web-flask-svc` Service hakkında bilgi görüntüleyin.

```bash
kubectl describe svc web-flask-svc
```

**Beklenen Çıktı:**
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

**Önemli:** `Endpoints` alanına dikkat edin - bunlar Pod IP'leridir. Service, selector'üne uyan Pod'ları otomatik olarak takip eder.

- forcurl pod'una gidin ve ClusterIP'li Service'i test edin.

```bash
kubectl exec -it forcurl -- sh
/ # curl <web-flask-svc service'inin IP'si>:3000
/ # ping web-flask-svc 
/ # curl web-flask-svc:3000
```

**Gözlem:** Service'e iki şekilde erişebilirsiniz:
1. Service'in ClusterIP'si kullanarak: `curl 10.109.125.55:3000`
2. Service'in DNS adını kullanarak: `curl web-flask-svc:3000`

- Gördüğümüz gibi, Kubernetes services otomatik DNS çözümlemesi sağlar. Service adı, Service'in ClusterIP'sine çözümlenen bir DNS girişi olur.

**Önemli Çıkarım:** Pod'lar silinip yeni IP'lerle yeniden oluşturulsa bile, Service IP'si ve DNS adı sabit kalır!

### NodePort Service Türü

- web-flask-svc service'inin türünü NodePort olarak değiştirerek, service'i cluster dışından erişilebilir hale getirmek için Node IP'sini ve statik bir port kullanın. `web-svc.yaml`'ı güncelleyin:

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

**Değişiklik:** Sadece `type` alanı `ClusterIP`'den `NodePort`'a değişti.

**NodePort ne yapar:** 
- Service'i her Node'un IP'sinde statik bir port'ta (NodePort) gösterir
- Otomatik olarak bir ClusterIP Service oluşturur (cluster içi erişim için)
- Dış trafiğin `<NodeIP>:<NodePort>` üzerinden Service'e erişmesine izin verir

- web-flask-svc service'ini apply komutuyla yapılandırın.

```bash
kubectl apply -f web-svc.yaml
```

**Beklenen Çıktı:**
```text
service/web-flask-svc configured
```

- Service'leri tekrar listeleyin. Kubernetes, service'i Node'un birincil IP adresini kullanarak 30000-32767 aralığında rastgele bir port'ta gösterir.

```bash
kubectl get svc -o wide
```

**Beklenen Çıktı:**
```text
NAME            TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE   SELECTOR
web-flask-svc   NodePort   10.98.173.110   <none>        3000:31234/TCP   30m   app=web-flask
```

**Dikkat:** PORT(S) sütunu artık `3000:31234/TCP` gösteriyor
- `3000` = Dahili ClusterIP portu
- `31234` = Dış NodePort (rastgele atanmış)

- Service'i cluster içinden test edin (hala aynı şekilde çalışır):

```bash
kubectl exec -it forcurl -- sh
/ # curl web-flask-svc:3000
/ # exit
```

- Artık service'e **cluster dışından** da erişebilirsiniz:

**Önemli Güvenlik Notu:** Dışarıdan erişmeden önce, node'unuzun security group'unda (AWS Security Group, firewall kuralları vb.) NodePort'u açmanız gerekir.

**Adımlar:**
1. Node'unuzun public IP'sini bulun:
```bash
kubectl get nodes -o wide
```

2. Security Group'unuzda `31234` portunu (veya atanan port'u) açın

3. Tarayıcı veya curl ile erişin:
```
http://<public-node-ip>:31234
```

- `http://<public-node-ip>:<node-port>` adresini ziyaret edebilir ve uygulamaya erişebiliriz. Load balancing'e dikkat edin - sayfayı birkaç kez yenileyin ve hostname'in değiştiğini fark edin (farklı Pod'ların istekleri karşıladığını gösterir).

**Not:** Node instance'ınızın security group'unda `<node-port>` Portunu açmayı unutmayın.

### Belirli Bir NodePort Tanımlama

- Service YAML dosyasına bir `nodePort` numarası ekleyerek belirli bir NodePort da tanımlayabiliriz. `web-svc.yaml`'ı güncelleyin:

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

**Değişiklik:** Tam olarak istediğimiz portu belirtmek için `nodePort: 30036` ekledik.

**Geçerli NodePort aralığı:** 30000-32767 (kube-apiserver'da yapılandırılabilir)

- web-flask-svc service'ini apply komutuyla tekrar yapılandırın.

```bash
kubectl apply -f web-svc.yaml
```

**Beklenen Çıktı:**
```text
service/web-flask-svc configured
```

- Service'leri listeleyin ve nodeport numarasının artık 30036 olduğunu fark edin.

```bash
kubectl get svc -o wide
```

**Beklenen Çıktı:**
```text
NAME            TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE   SELECTOR
web-flask-svc   NodePort   10.98.173.110   <none>        3000:30036/TCP   35m   app=web-flask
```

- Security group'unuzu 30036 portuna izin verecek şekilde güncelleyin, ardından erişin:

```
http://<public-node-ip>:30036
```

### Endpoint'leri Anlamak

Pod'lar gelip gittikçe (scale up ve down, başarısızlıklar, rolling update'ler vb.), Service, Pod listesini dinamik olarak günceller. Bunu label selector ve **Endpoint object** adı verilen bir yapının kombinasyonu ile yapar.

Oluşturulan her Service, otomatik olarak ilişkili bir Endpoint object'i alır. Bu Endpoint object'i, Service'in label selector'üne uyan tüm Pod'ların dinamik bir listesidir.

Kubernetes, cluster'daki mevcut Pod listesine karşı sürekli olarak Service'in label selector'ünü değerlendirir. Selector ile eşleşen yeni Pod'lar Endpoint object'ine eklenir ve kaybolan Pod'lar kaldırılır. Bu, Service'in Pod'lar gelip gittikçe güncel tutulmasını sağlar.

**Nasıl çalışır:**
1. Service, eşleşen Pod'ları bulmak için `selector` kullanır
2. Kubernetes, Service ile aynı ada sahip bir Endpoint object'i oluşturur
3. Endpoint controller, Pod değişikliklerini sürekli izler
4. Pod'lar eklendiğinde/kaldırıldığında, Endpoint'ler otomatik güncellenir
5. Service, trafiği yönlendirmek için Endpoint listesini kullanır

- `Endpoints`'in dokümantasyonunu ve alanlarını görün.

```bash
kubectl explain ep
```

- Endpoint'leri listeleyin.

```bash
kubectl get ep -o wide
```

**Beklenen Çıktı:**
```text
NAME            ENDPOINTS                                         AGE
kubernetes      192.168.1.100:6443                                5h
web-flask-svc   10.244.1.7:5000,10.244.1.8:5000,10.244.1.9:5000   40m
```

**Dikkat:** Endpoint'ler, `kubectl get pods -o wide` çalıştırdığımızda gördüğümüz Pod IP'leriyle eşleşiyor!

- Deployment'ı on replica'ya ölçeklendirin ve `Endpoints`'leri listeleyin.

```bash
kubectl scale deploy web-flask-deploy --replicas=10
```

**Beklenen Çıktı:**
```text
deployment.apps/web-flask-deploy scaled
```

- `Endpoints`'leri listeleyin ve Service'in label selector ile eşleşen Pod'ların her zaman güncel bir listesine sahip ilişkili bir `Endpoint` object'i olduğunu açıklayın.

```bash
kubectl get ep -o wide 
```

**Beklenen Çıktı:**
```text
NAME            ENDPOINTS                                                          AGE
web-flask-svc   10.244.1.10:5000,10.244.1.11:5000,10.244.1.12:5000 + 7 more...   42m
```

**Gözlem:** Endpoint'ler otomatik olarak 10 Pod'u da içerecek şekilde güncellendi!

- Bunu Pod IP'lerini kontrol ederek doğrulayın:

```bash
kubectl get pods -o wide
```

- Şimdi 2 replica'ya scale down yapın:

```bash
kubectl scale deploy web-flask-deploy --replicas=2
kubectl get ep web-flask-svc
```

**Gözlem:** Endpoint'ler, silinen Pod'ları otomatik olarak kaldırdı.

**Önemli Çıkarım:** Endpoint controller, Pod değişikliklerini sürekli izler ve Service'in endpoint listesini güncel tutar. Bu, Service'lerin Pod kayması olmasına rağmen nasıl kararlı networking sağladığıdır.

> Herhangi bir node'da bir tarayıcı açın ve `load balancing` davranışını gösterin. (Host IP'ye ve node adına dikkat edin ve `host IP'lerin` ve `endpoint'lerin` aynı olduğunu fark edin)
>
> http://[public-node-ip]:[node-port]
>
> Sayfayı birkaç kez yenileyin ve hostname/IP'nin değiştiğini izleyin, bu da trafiğin tüm backend Pod'lar arasında load-balance edildiğini gösterir.

### LoadBalancer Service Türü (Cloud Provider'a Özgü)

**Not:** LoadBalancer türü tipik olarak cloud ortamlarında (AWS, GCP, Azure) kullanılır; burada cloud provider harici bir load balancer sağlayabilir.

- `web-svc.yaml`'ı LoadBalancer türünü kullanacak şekilde güncelleyin:

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

**Beklenen Çıktı (cloud provider'da):**
```text
NAME            TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)          AGE
web-flask-svc   LoadBalancer   10.98.173.110   a1234567890abcdef.us-east-1.elb.amazonaws.com                          3000:31234/TCP   45m
```

**Ne olur:**
- Cloud provider harici bir load balancer sağlar (örn. AWS ELB/ALB)
- Trafik akışı: Harici LB → NodePort → Service → Pod'lar
- EXTERNAL-IP alanında herkese açık erişilebilir bir hostname/IP alırsınız

**Not:** Yerel cluster'larda (minikube, kind, bare metal), EXTERNAL-IP `<pending>` olarak kalır çünkü load balancer oluşturacak bir cloud provider yoktur.

### Farklı Bir Namespace'teki Service'e Bağlanma

- Kubernetes'in DNS için bir eklentisi vardır (CoreDNS), her Service için bir DNS kaydı oluşturur. Format şöyledir:

`<service-name>.<namespace>.svc.cluster.local`

**DNS Çözümleme Kuralları:**
- **Aynı Namespace** içindeki Service'ler birbirlerini sadece service adını kullanarak bulabilir (örn. `web-flask-svc`)
- **Farklı Namespace'lerdeki** Service'ler tam formatı kullanmalıdır: `<service-name>.<namespace-name>` veya FQDN

- Bunu bir örnekle anlayalım.

- İlk olarak, deployment ve service'i default namespace'den kaldırın:

```bash
kubectl delete -f web-flask.yaml -f web-svc.yaml
```

**Alternatif (service-lessons dizinindeyseniz):**
```bash
kubectl delete -f .
```

**Beklenen Çıktı:**
```text
deployment.apps "web-flask-deploy" deleted
service "web-flask-svc" deleted
```

- Bir namespace oluşturun ve adını `demo` koyun.

```bash
kubectl create namespace demo
```

**Beklenen Çıktı:**
```text
namespace/demo created
```

- `web-flask.yaml` dosyasını `demo` namespace'inde deploy edecek şekilde güncelleyin:

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

**Değişiklik:** metadata'ya `namespace: demo` eklendi.

- `web-svc.yaml` dosyasını `demo` namespace'inde Service oluşturacak şekilde güncelleyin:

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

**Değişiklik:** metadata'ya `namespace: demo` eklendi.

- Deployment ve service'i oluşturun:

```bash
kubectl apply -f web-flask.yaml -f web-svc.yaml
```

**Beklenen Çıktı:**
```text
deployment.apps/web-flask-deploy created
service/web-flask-svc created
```

- Tüm namespace'leri gösterin:

```bash
kubectl get ns
```

**Beklenen Çıktı:**
```text
NAME              STATUS   AGE
default           Active   6h
demo              Active   2m
kube-node-lease   Active   6h
kube-public       Active   6h
kube-system       Active   6h
```

- Hem `demo` hem de `default` namespace'lerindeki nesneleri listeleyin:

```bash
kubectl get deploy -n demo
kubectl get pod -n demo
kubectl get svc -n demo
```

**Beklenen Çıktı (demo namespace):**
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

**Beklenen Çıktı (default namespace):**
```text
NAME      READY   STATUS    RESTARTS   AGE
forcurl   1/1     Running   0          15m

NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   6h
```

**Gözlem:** `forcurl` Pod'u `default` namespace'indeyken, Flask uygulamamız `demo` namespace'inde.

- forcurl container'a giriş yapın ve `demo` namespace'indeki `web-flask-svc`'ye erişmeyi deneyin:

```bash
kubectl exec -it forcurl -- sh
```

**Test 1: Sadece service adını kullanmayı deneyin (BAŞARISIZ olacak):**
```bash
/ # curl web-flask-svc:3000
```
**Sonuç:** Farklı namespace'lerde olduğumuz için "could not resolve host" hatası vererek başarısız olur.

**Test 2: Namespace-qualified adı kullanın:**
```bash
/ # curl web-flask-svc.demo:3000
```
**Sonuç:** Başarılı! Namespace'i belirttiğimiz için çalışır.

**Test 3: Fully Qualified Domain Name (FQDN) kullanın:**
```bash
/ # curl web-flask-svc.demo.svc.cluster.local:3000
```
**Sonuç:** Bu da çalışır! Bu tam DNS adıdır.

**DNS Adı Dökümü:**
- `web-flask-svc` = Service adı
- `demo` = Namespace adı
- `svc` = Bunun bir Service olduğunu gösterir
- `cluster.local` = Cluster domain (varsayılan)

**Önemli Çıkarımlar:**
- Aynı namespace: Sadece `<service-name>` kullanın
- Farklı namespace: `<service-name>.<namespace>` kullanın
- Tam FQDN: `<service-name>.<namespace>.svc.cluster.local`

- Container'dan çıkın:

```bash
/ # exit
```

- Tüm nesneleri silin:

```bash
kubectl delete -f web-flask.yaml -f web-svc.yaml
kubectl delete ns demo
```

**Beklenen Çıktı:**
```text
deployment.apps "web-flask-deploy" deleted
service "web-flask-svc" deleted
namespace "demo" deleted
```

**Not:** Bir namespace'i silmek, içindeki tüm kaynakları otomatik olarak siler.

## Part 3 - Service Türleri Özeti

### ClusterIP (Varsayılan)
- **Kullanım senaryosu:** Sadece dahili cluster iletişimi
- **Erişim:** Yalnızca cluster içinden
- **DNS:** `<service-name>` veya `<service-name>.<namespace>.svc.cluster.local`
- **Örnek:** Birbirleriyle konuşan microservice'ler, veritabanları

### NodePort
- **Kullanım senaryosu:** Service'i her node'un IP'sinde statik bir port'ta gösterme
- **Erişim:** Cluster dışından `<NodeIP>:<NodePort>` üzerinden
- **Port aralığı:** 30000-32767 (varsayılan)
- **Örnek:** Geliştirme/test ortamları, küçük deployment'lar
- **Not:** Her service, TÜM node'larda kendi portunu alır

### LoadBalancer
- **Kullanım senaryosu:** Cloud ortamlar (AWS, GCP, Azure)
- **Erişim:** Cloud provider'ın load balancer'ı üzerinden (harici IP/hostname alır)
- **Örnek:** Harici erişim gerektiren production uygulamaları
- **Not:** Cloud load balancer ile ilişkili maliyetler
- **Nasıl çalışır:** NodePort oluşturur + harici LB sağlar → NodePort → Service → Pod'lar

### ExternalName
- **Kullanım senaryosu:** Bir service'i harici bir DNS adına eşleme
- **Örnek:** Harici veritabanına erişim, üçüncü taraf API
```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: mydb.example.com
```
- **Not:** Selector gerekli değil, sadece CNAME kaydı döndürür

## Sorun Giderme İpuçları

### Service Çalışmıyor mu?

**Kontrol 1: Endpoint'lerin var olduğunu doğrulayın**
```bash
kubectl get ep <service-name>
```
Boşsa, selector hiçbir Pod ile eşleşmiyor.

**Kontrol 2: Pod label'larını doğrulayın**
```bash
kubectl get pods --show-labels
```
Pod label'ları Service selector ile eşleşiyor mu?

**Kontrol 3: Pod'un hazır olduğunu doğrulayın**
```bash
kubectl get pods
```
Pod, Running durumunda olmalı ve READY 1/1 göstermeli.

**Kontrol 4: Önce cluster içinden test edin**
```bash
kubectl run test --image=busybox --rm -it -- sh
/ # wget -O- http://<service-name>:<port>
```

**Kontrol 5: Service detaylarını kontrol edin**
```bash
kubectl describe svc <service-name>
```
Endpoints, Selector ve Events bölümlerine bakın.

**Kontrol 6: Port uyuşmazlığı var mı?**
- `port` = Service bu port'ta dinler
- `targetPort` = Pod bu port'ta dinler (Deployment'taki containerPort ile eşleşmeli)
- `nodePort` = Harici erişim portu (sadece NodePort/LoadBalancer)

**Yaygın hatalar:**
- Selector, Pod label'ları ile eşleşmiyor (yazım hatası, yanlış label)
- Yanlış targetPort (containerPort ile eşleşmiyor)
- Container aslında port'ta dinlemiyor
- Trafiği engelleyen network policy'ler
- CoreDNS çalışmıyor: `kubectl get pods -n kube-system`

## Özet

Bu uygulamalı eğitimde şunları öğrendiniz:

✅ Kubernetes Services'in dinamik Pod'lar için nasıl kararlı networking sağladığını

✅ CoreDNS aracılığıyla service discovery (otomatik DNS çözümlemesi)

✅ Üç ana Service türü:
   - **ClusterIP**: Dahili cluster iletişimi
   - **NodePort**: Node IP ve statik port üzerinden harici erişim
   - **LoadBalancer**: Cloud provider load balancer (harici erişim)

✅ Endpoint'lerin Pod değişikliklerini otomatik olarak nasıl takip ettiğini

✅ DNS kullanarak namespace'ler arası service iletişimi

✅ Service bağlantı sorunlarını nasıl gidereceğinizi

**Hatırlanması Gereken Temel Kavramlar:**
- Pod'lar geçicidir (yeniden oluşturulduklarında yeni IP'ler alırlar)
- Service'ler kararlı IP'ler ve DNS adları sağlar
- Label selector'ler, Service'leri Pod'lara bağlar
- Endpoint controller'lar, service endpoint'lerini güncel tutar
- DNS, service'leri keşfedilebilir yapar
- Farklı kullanım senaryoları için farklı service türleri

## Ek Kaynaklar

- [Kubernetes Services Resmi Dokümantasyonu](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Services ve Pods için DNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

---

**Uygulamalı Eğitimin Sonu**
