# Kubernetes Pod Scheduling - Detaylı Rehber

Bu eğitim, Kubernetes'te pod scheduling (pod planlama) konusunu derinlemesine öğretmeyi amaçlar. Pod'ların hangi node'larda çalışacağını kontrol etmenin farklı yöntemlerini örneklerle inceleyeceğiz.

## 📚 Öğrenme Hedefleri

Bu eğitimin sonunda şunları yapabileceksiniz:

- Pod'ları belirli node'lara nasıl planlayacağınızı öğreneceksiniz
- nodeName, nodeSelector, Node Affinity gibi farklı scheduling yöntemlerini anlayacaksınız
- Pod Affinity ile pod'ların birbirine göre konumlandırılmasını öğreneceksiniz
- Taint ve Toleration kullanarak node'ları nasıl koruyacağınızı bileceksiniz

## 📋 İçindekiler

1. [Kubernetes Cluster Kurulumu](#part-1---kubernetes-cluster-kurulumu)
2. [Pod Scheduling Temel Kavramlar](#part-2---pod-scheduling-temel-kavramlar)
3. [nodeName ile Scheduling](#part-3---nodename-ile-scheduling)
4. [nodeSelector ile Scheduling](#part-4---nodeselector-ile-scheduling)
5. [Node Affinity ile Gelişmiş Scheduling](#part-5---node-affinity-ile-gelişmiş-scheduling)
6. [Pod Affinity ile Pod Bazlı Planlama](#part-6---pod-affinity-ile-pod-bazlı-planlama)
7. [Taint ve Toleration](#part-7---taint-ve-toleration)

---

## Part 1 - Kubernetes Cluster Kurulumu

### Gereksinimler

- 2 node'lu bir Kubernetes cluster (1 control plane, 1 worker node)
- Ubuntu 22.04 LTS (veya 20.04 LTS)
- Minimum 2 CPU, 4GB RAM (her node için)

### Alternatif Test Ortamı

> **Not:** Eğer kendi Kubernetes cluster'ınızı kurmakta sorun yaşıyorsanız, aşağıdaki online platformları kullanabilirsiniz:
> - https://killercoda.com/playgrounds/scenario/kubernetes
> - https://labs.play-with-k8s.com/

### Cluster Durumunu Kontrol Etme

Kubernetes cluster'ınızın çalıştığından ve node'ların hazır olduğundan emin olun:

```bash
# Cluster bilgilerini görüntüle
kubectl cluster-info

# Çıktı örneği:
# Kubernetes control plane is running at https://192.168.1.10:6443
# CoreDNS is running at https://192.168.1.10:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

```bash
# Node'ları listele ve durumlarını kontrol et
kubectl get nodes -o wide

# Çıktı örneği:
# NAME           STATUS   ROLES           AGE   VERSION
# kube-master    Ready    control-plane   10m   v1.30.0
# kube-worker    Ready    <none>          8m    v1.30.0
```

```bash
# Daha detaylı node bilgisi için
kubectl get nodes --show-labels
```

---

## Part 2 - Pod Scheduling Temel Kavramlar

### Scheduling Nedir?

**Scheduling**, Kubernetes'te pod'ların hangi node üzerinde çalışacağını belirleme sürecidir. Kubernetes, bu işlemi otomatik olarak yapar ancak biz belirli durumlarda bu süreci kontrol edebiliriz.

### Scheduler Nasıl Çalışır?

1. **Yeni Pod Algılama**: Scheduler, henüz bir node'a atanmamış yeni pod'ları sürekli izler
2. **Uygun Node Bulma**: Her pod için en uygun node'u bulmaya çalışır
3. **Kaynak Kontrolü**: Node'ların CPU, RAM gibi kaynaklarını kontrol eder
4. **Planlama**: Pod'u uygun node'a atar

### kube-scheduler

- Kubernetes'in varsayılan scheduler'ıdır
- Control plane'in bir parçası olarak çalışır
- Her yeni pod için otomatik olarak en uygun node'u seçer

### Feasible (Uygun) Node

Bir pod için gerekli tüm koşulları karşılayan node'lara **feasible node** denir. Eğer hiçbir node uygun değilse, pod **Pending** durumunda kalır.

### Pod'ları Neden Manuel Planlarız?

- **Özel Donanım Gereksinimleri**: GPU, SSD gibi özel kaynaklara ihtiyaç olabilir
- **Veri Yerelliği**: Veritabanı ve uygulama pod'larını aynı node'da çalıştırmak
- **Lisans Kısıtlamaları**: Bazı yazılımlar sadece belirli node'larda çalışmalıdır
- **Compliance**: Yasal düzenlemeler belirli coğrafi bölgelerde çalışmayı gerektirebilir

---

## Part 3 - nodeName ile Scheduling

### nodeName Nedir?

`nodeName`, bir pod'u doğrudan belirli bir node'a atamak için kullanılan en basit yöntemdir. PodSpec içinde node adını belirterek scheduler'ı tamamen bypass ederiz.

### İlk Test: Varsayılan Davranış

Control plane node'lar varsayılan olarak pod'ları kabul etmez (taint nedeniyle). Bunu görelim:

```bash
# nginx-deploy.yaml dosyasını oluştur
cat > nginx-deploy.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    environment: dev
spec:
  replicas: 15
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
        image: nginx:1.27-alpine  # Alpine sürümü daha hafif
        ports:
        - containerPort: 80
        resources:  # Kaynak limitleri ekliyoruz
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF
```

```bash
# Deployment'ı oluştur
kubectl apply -f nginx-deploy.yaml
```

```bash
# Pod'ları listele ve hangi node'da çalıştıklarını gör
kubectl get pods -o wide

# Çıktı: Tüm pod'lar sadece worker node'da çalışıyor olacak
```

```bash
# Deployment'ı sil
kubectl delete -f nginx-deploy.yaml
```

### Control Plane'i Worker Node Olarak Kullanma

İki worker node'umuz yoksa, control plane'i de worker olarak kullanabiliriz:

```bash
# Control plane'deki taint'i kaldır
kubectl taint nodes kube-master node-role.kubernetes.io/control-plane:NoSchedule-

# Açıklama:
# - 'kube-master': Node adı (sizin node adınızla değiştirin)
# - 'node-role.kubernetes.io/control-plane:NoSchedule': Kaldırılacak taint
# - Son '-': Taint'i kaldır anlamına gelir
```

```bash
# Taint'in kaldırıldığını kontrol et
kubectl describe node kube-master | grep -i taint

# Çıktı: "Taints: <none>" görmeli
```

```bash
# Deployment'ı tekrar oluştur
kubectl apply -f nginx-deploy.yaml
```

```bash
# Şimdi pod'lar her iki node'da da dağıtılmış olmalı
kubectl get pods -o wide

# Çıktı: Pod'lar hem master hem worker node'da çalışıyor
```

```bash
# Temizlik
kubectl delete -f nginx-deploy.yaml
```

### nodeName Kullanımı

```bash
# Node isimlerini öğren
kubectl get nodes

# Çıktı örneği:
# NAME           STATUS   ROLES           AGE
# kube-master    Ready    control-plane   1h
# kube-worker    Ready    <none>          1h
```

`nginx-deploy.yaml` dosyasını güncelleyin:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    environment: dev
spec:
  replicas: 15
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
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
      nodeName: kube-master  # ← Bu satırı ekleyin (node adınızla değiştirin)
```

```bash
# Deployment'ı oluştur
kubectl apply -f nginx-deploy.yaml
```

```bash
# Pod'ların sadece master node'da çalıştığını gör
kubectl get pods -o wide

# Çıktı: Tüm pod'lar kube-master node'unda
```

```bash
# Temizlik
kubectl delete -f nginx-deploy.yaml
```

### ⚠️ nodeName Kullanımının Sınırlamaları

1. **Node Yoksa Pod Çalışmaz**: Belirtilen node adı yoksa pod hiç çalışmaz
2. **Kaynak Yetersizliği**: Node'da yeterli kaynak yoksa pod hata verir (OutOfMemory, OutOfCPU)
3. **Cloud Ortamlarında Risk**: Cloud'da node isimleri değişebilir
4. **Esneklik Kaybı**: Scheduler'ın akıllı kararlarından faydalanamayız
5. **Ölçeklenemez**: Çok sayıda pod ve node ile yönetimi zorlaşır

> **Önerilen Kullanım**: nodeName sadece debugging veya çok özel durumlar için kullanılmalı. Production ortamlarında nodeSelector veya Node Affinity tercih edilmelidir.

---

## Part 4 - nodeSelector ile Scheduling

### nodeSelector Nedir?

`nodeSelector`, node'lara etiket (label) atayarak pod'ları bu etiketlere göre planlamamıza olanak sağlar. nodeName'den daha esnek ve yönetilebilir bir yöntemdir.

### Kullanım Senaryosu

Farklı kapasitelere sahip node'larımız olduğunu düşünelim:
- **Büyük node'lar**: Yüksek CPU ve RAM
- **Küçük node'lar**: Sınırlı kaynaklar

Kaynak yoğun uygulamaları büyük node'lara yönlendirmek istiyoruz.

### Node'lara Label Ekleme

```bash
# Genel syntax
kubectl label nodes <node-name> <label-key>=<label-value>

# Örnek: master node'a size=large etiketi ekle
kubectl label nodes kube-master size=large

# Başarılı çıktı:
# node/kube-master labeled
```

```bash
# Worker node'a size=small etiketi ekle (karşılaştırma için)
kubectl label nodes kube-worker size=small
```

### Label'ları Kontrol Etme

```bash
# Tüm node'ların label'larını göster
kubectl get nodes --show-labels

# Çıktı örneği:
# NAME          STATUS   ROLES           AGE   LABELS
# kube-master   Ready    control-plane   2h    size=large,kubernetes.io/hostname=kube-master,...
# kube-worker   Ready    <none>          2h    size=small,kubernetes.io/hostname=kube-worker,...
```

```bash
# Belirli bir node'un detaylı label bilgisi
kubectl describe node kube-master | grep -A 10 Labels

# Veya sadece custom label'ları görmek için
kubectl get nodes -L size

# Çıktı:
# NAME          STATUS   ROLES           AGE   SIZE
# kube-master   Ready    control-plane   2h    large
# kube-worker   Ready    <none>          2h    small
```

### nodeSelector ile Deployment Oluşturma

`nginx-deploy.yaml` dosyasını güncelleyin:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    environment: dev
spec:
  replicas: 15
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
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
      nodeSelector:        # ← nodeSelector bloğunu ekleyin
        size: large        # ← Sadece size=large etiketli node'larda çalışır
```

```bash
# Deployment'ı oluştur
kubectl apply -f nginx-deploy.yaml
```

```bash
# Pod'ların sadece large node'da çalıştığını kontrol et
kubectl get pods -o wide

# Çıktı: Tüm pod'lar kube-master (size=large) node'unda
```

```bash
# Pod'lardan birinin detayını incele
kubectl describe pod <pod-name> | grep -A 5 "Node-Selectors"

# Çıktı:
# Node-Selectors:  size=large
```

### Olmayan Label ile Test

```bash
# Olmayan bir label ekleyelim
kubectl label nodes kube-master disk=ssd
```

`nginx-deploy.yaml` dosyasını güncelleyin:

```yaml
      nodeSelector:
        size: large
        disk: ssd    # ← İkinci bir koşul eklendi
```

```bash
# Deployment'ı güncelle
kubectl apply -f nginx-deploy.yaml

# Pod'lar sadece her iki etikete de sahip node'larda çalışacak
```

```bash
# Temizlik
kubectl delete -f nginx-deploy.yaml

# Label'ları kaldır (opsiyonel)
kubectl label nodes kube-master size-
kubectl label nodes kube-master disk-
kubectl label nodes kube-worker size-
```

### nodeSelector'ın Avantajları

✅ nodeName'den daha esnek  
✅ Okunması ve anlaşılması kolay  
✅ Label'lar node'lara göre kolayca değiştirilebilir  
✅ Çoklu koşul desteği (AND mantığı)  

### nodeSelector'ın Sınırlamaları

❌ Sadece AND mantığı (tüm koşullar sağlanmalı)  
❌ OR mantığı yok (A veya B)  
❌ "Değil" koşulu yok (NOT)  
❌ Tercih belirtme yok (preferred vs required)  

> **Sonraki Adım**: Bu sınırlamaları aşmak için **Node Affinity** kullanacağız.

---

## Part 5 - Node Affinity ile Gelişmiş Scheduling

### Node Affinity Nedir?

**Node Affinity**, nodeSelector'ın gelişmiş versiyonudur. Daha karmaşık ve esnek scheduling kuralları belirlememize olanak sağlar.

### Node Affinity Türleri

Kubernetes'te iki ana Node Affinity türü vardır:

1. **requiredDuringSchedulingIgnoredDuringExecution** (Zorunlu)
   - Pod ancak koşullar sağlanırsa schedule edilir
   - nodeSelector'a benzer ama daha güçlü

2. **preferredDuringSchedulingIgnoredDuringExecution** (Tercihli)
   - Scheduler bu koşulları sağlamaya çalışır ama garantilemez
   - Uygun node yoksa başka node'lara da yerleştirebilir

### Terminoloji Açıklaması

| Tür | DuringScheduling | DuringExecution |
|-----|------------------|-----------------|
| requiredDuringScheduling... | **required** (Zorunlu) | **Ignored** (Görmezden gelinir) |
| preferredDuringScheduling... | **preferred** (Tercihli) | **Ignored** (Görmezden gelinir) |

**DuringScheduling**: Pod ilk kez yerleştirilirken  
**DuringExecution**: Pod çalışırken node label'ları değişirse  
**Ignored**: Pod çalışmaya devam eder (yeniden schedule edilmez)

> **Not**: Gelecekte `requiredDuringSchedulingRequiredDuringExecution` gibi türler de eklenebilir (pod çalışırken koşullar bozulursa pod başka yere taşınır).

### Hazırlık: Node Label'ları

```bash
# Master node'a size=large etiketi ekle
kubectl label nodes kube-master size=large

# Worker node'a size=medium etiketi ekle
kubectl label nodes kube-worker size=medium

# Label'ları kontrol et
kubectl get nodes -L size
```

### 1. requiredDuringScheduling (Zorunlu Affinity)

`nginx-deploy.yaml` dosyasını güncelleyin:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    environment: dev
spec:
  replicas: 15
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
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:  # ← Zorunlu affinity
            nodeSelectorTerms:
            - matchExpressions:
              - key: size                # ← Label key
                operator: In             # ← Operatör
                values:
                - large                  # ← İzin verilen değer(ler)
                - medium
```

**Operator Türleri:**

- `In`: Value listesindeki değerlerden biri olmalı (OR mantığı)
- `NotIn`: Value listesindeki değerlerden hiçbiri olmamalı
- `Exists`: Key mevcut olmalı (value önemli değil)
- `DoesNotExist`: Key mevcut olmamalı
- `Gt`: Greater than (sayısal değerler için)
- `Lt`: Less than (sayısal değerler için)

```bash
# Deployment'ı oluştur
kubectl apply -f nginx-deploy.yaml
```

```bash
# Pod'ları kontrol et
kubectl get pods -o wide

# Çıktı: Pod'lar hem large hem medium etiketli node'larda çalışıyor
```

### Test: Label Değiştirme

```bash
# Master node'un label'ını değiştirelim
kubectl label nodes kube-master size=small --overwrite

# Pod'lar ne oldu?
kubectl get pods -o wide

# Çıktı: Mevcut pod'lar çalışmaya devam ediyor (IgnoredDuringExecution)
# Ancak yeni pod'lar artık sadece worker node'a yerleştiriliyor
```

```bash
# Deployment'ı ölçeklendirerek test edelim
kubectl scale deployment nginx-deployment --replicas=20

# Yeni pod'lar nerede?
kubectl get pods -o wide

# Çıktı: Yeni pod'lar sadece size=medium olan worker node'da
```

```bash
# Label'ı geri alalım
kubectl label nodes kube-master size=large --overwrite

# Temizlik
kubectl delete -f nginx-deploy.yaml
```

### 2. preferredDuringScheduling (Tercihli Affinity)

`nginx-deploy.yaml` dosyasını güncelleyin:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    environment: dev
spec:
  replicas: 15
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
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:  # ← Tercihli affinity
          - weight: 80                    # ← Yüksek öncelik (1-100 arası)
            preference:
              matchExpressions:
              - key: size
                operator: In
                values:
                - large
          - weight: 20                    # ← Düşük öncelik
            preference:
              matchExpressions:
              - key: size
                operator: In
                values:
                - medium
```

**Weight (Ağırlık) Nasıl Çalışır?**

- Her tercih 1-100 arası bir ağırlığa sahip olabilir
- Scheduler tüm koşulları karşılayan node'ları bulur
- Her node için weight değerlerini toplar
- En yüksek skora sahip node tercih edilir
- **Ancak garantilemez** - kaynak yetersizse düşük skorlu node'a da yerleştirebilir

```bash
# Deployment'ı oluştur
kubectl apply -f nginx-deploy.yaml
```

```bash
# Pod'ları kontrol et
kubectl get pods -o wide

# Çıktı: Çoğunlukla large etiketli node'da ama bazıları medium'da da olabilir
```

### Karma Kullanım (Required + Preferred)

En güçlü yaklaşım: Zorunlu koşullar + Tercihler

```yaml
      affinity:
        nodeAffinity:
          # Önce zorunlu koşul: Sadece Linux node'lar
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/os
                operator: In
                values:
                - linux
          # Sonra tercih: Büyük node'lar tercih edilsin
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: size
                operator: In
                values:
                - large
          - weight: 50
            preference:
              matchExpressions:
              - key: disk
                operator: In
                values:
                - ssd
```

Bu örnekte:
1. Pod mutlaka Linux node'a yerleşir (required)
2. Mümkünse size=large node'a yerleşir (weight: 100)
3. SSD'li node varsa o da tercih edilir (weight: 50)

```bash
# Temizlik
kubectl delete -f nginx-deploy.yaml

# Label'ları kaldır (opsiyonel)
kubectl label nodes kube-master size-
kubectl label nodes kube-worker size-
```

### Node Affinity Özeti

| Özellik | nodeSelector | Node Affinity (Required) | Node Affinity (Preferred) |
|---------|-------------|-------------------------|--------------------------|
| Karmaşıklık | Basit | Orta | Orta |
| OR mantığı | ❌ | ✅ | ✅ |
| NOT mantığı | ❌ | ✅ | ✅ |
| Tercih belirleme | ❌ | ❌ | ✅ |
| Ağırlıklandırma | ❌ | ❌ | ✅ |
| Kullanım senaryosu | Basit etiket eşleştirme | Kesin kısıtlamalar | Esnek tercihler |

---

## Part 6 - Pod Affinity ile Pod Bazlı Planlama

### Pod Affinity Nedir?

**Pod Affinity**, pod'ları node etiketlerine göre değil, **diğer pod'lara göre** yerleştirmemize olanak sağlar. 

### Kullanım Senaryoları

1. **Veri Yerelliği**: Veritabanı ve uygulama pod'larını aynı node'da çalıştır (düşük latency)
2. **Mikroservis İletişimi**: Sık iletişim kuran servisleri yakın tut
3. **Paylaşımlı Kaynak**: Aynı cache veya shared volume'ü kullanacak pod'lar
4. **Anti-Affinity**: Pod'ları farklı node'lara dağıt (yüksek erişilebilirlik)

### Örnek Senaryo

Bir e-ticaret uygulaması:
- **Backend Pod (ondia-db)**: Veritabanı
- **Frontend Deployment (ondiashop)**: Web uygulaması

Frontend pod'larını backend pod ile aynı node'da çalıştırmak istiyoruz.

### Adım 1: Backend Pod Oluşturma

```bash
# ondia-db.yaml dosyasını oluştur
cat > ondia-db.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ondia-db
  labels:
    tier: db           # ← Bu label'ı kullanarak pod'u tanımlayacağız
    app: ondiashop
spec:
  containers:
  - name: ondia-db
    image: mysql:8.0
    env:
    - name: MYSQL_ROOT_PASSWORD
      value: "secret123"
    - name: MYSQL_DATABASE
      value: "ondiashop"
    ports:
    - containerPort: 3306
    resources:
      requests:
        memory: "256Mi"
        cpu: "200m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  restartPolicy: Always
EOF
```

```bash
# Pod'u oluştur
kubectl apply -f ondia-db.yaml
```

```bash
# Pod'un hangi node'da çalıştığını öğren
kubectl get pod ondia-db -o wide

# Çıktı örneği:
# NAME       READY   STATUS    RESTARTS   AGE   IP           NODE
# ondia-db   1/1     Running   0          10s   10.244.1.5   kube-worker
```

### Adım 2: Frontend Deployment (Pod Affinity ile)

```bash
# ondiashop-deploy.yaml dosyasını oluştur
cat > ondiashop-deploy.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ondiashop
  labels:
    app: ondiashop
spec:
  replicas: 5
  selector:
    matchLabels:
      app: ondiashop
      tier: frontend
  template:
    metadata:
      labels:
        app: ondiashop
        tier: frontend
    spec:
      containers:
      - name: ondiashop
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
      affinity:
        podAffinity:                                            # ← Pod Affinity başlangıcı
          requiredDuringSchedulingIgnoredDuringExecution:       # ← Zorunlu
          - labelSelector:                                      # ← Hangi pod'a göre?
              matchExpressions:
              - key: tier                                       # ← Label key
                operator: In                                    # ← Operatör
                values:
                - db                                            # ← Aranacak değer
            topologyKey: "kubernetes.io/hostname"               # ← Topology key (önemli!)
EOF
```

**topologyKey Açıklaması:**

- `kubernetes.io/hostname`: Aynı node (hostname)
- `topology.kubernetes.io/zone`: Aynı availability zone
- `topology.kubernetes.io/region`: Aynı region

```bash
# Deployment'ı oluştur
kubectl apply -f ondiashop-deploy.yaml
```

```bash
# Tüm pod'ları kontrol et
kubectl get pods -o wide

# Çıktı: Tüm ondiashop pod'ları ondia-db ile aynı node'da (kube-worker)
```

```bash
# Pod affinity'yi kontrol et
kubectl describe pod <ondiashop-pod-name> | grep -A 10 "Pod Affinity"
```

### Test: Backend Pod'u Taşıma

```bash
# Backend pod'u sil (farklı node'da yeniden oluşacak mı diye test)
kubectl delete pod ondia-db

# Yeniden oluştur
kubectl apply -f ondia-db.yaml

# Pod'ları kontrol et
kubectl get pods -o wide

# Frontend pod'lar backend'in yeni konumunu takip eder mi?
# Hayır! IgnoredDuringExecution - mevcut pod'lar yerinde kalır
# Ancak yeni oluşturulacak pod'lar yeni konuma gider
```

```bash
# Frontend'i yeniden başlat
kubectl rollout restart deployment ondiashop

# Şimdi frontend pod'lar backend'in yanına yerleşti
kubectl get pods -o wide
```

### Pod Anti-Affinity (Yüksek Erişilebilirlik)

Pod'ları **farklı** node'lara dağıtmak için `podAntiAffinity` kullanırız:

```yaml
      affinity:
        podAntiAffinity:                                        # ← Anti-Affinity
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - ondiashop
            topologyKey: "kubernetes.io/hostname"               # ← Farklı hostname'ler
```

Bu konfigürasyon, aynı `app=ondiashop` etiketli pod'ların **farklı** node'larda çalışmasını sağlar.

### Preferred Pod Affinity

Zorunlu yerine tercihli de yapabiliriz:

```yaml
      affinity:
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:      # ← Tercihli
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: tier
                  operator: In
                  values:
                  - db
              topologyKey: "kubernetes.io/hostname"
```

```bash
# Temizlik
kubectl delete -f ondiashop-deploy.yaml
kubectl delete -f ondia-db.yaml
```

### Pod Affinity/Anti-Affinity Özeti

| Tür | Kullanım Amacı | Örnek |
|-----|---------------|-------|
| **podAffinity** | Pod'ları bir araya getir | DB ve App aynı node'da |
| **podAntiAffinity** | Pod'ları dağıt | Web replicas farklı node'larda |
| **required** | Kesinlikle uygulanır | Production kritik uygulamalar |
| **preferred** | Mümkünse uygulanır | Dev/Test ortamları |

---

## Part 7 - Taint ve Toleration

### Taint ve Toleration Nedir?

- **Taint**: Node'lara uygulanan bir "itme" mekanizması (pod'ları reddetme)
- **Toleration**: Pod'lara uygulanan bir "tolerans" mekanizması (taint'leri tolere etme)

### Analoji

Taint ve Toleration'ı şöyle düşünebiliriz:
- **Taint**: "Bu alana girmek için özel izin gerekir" tabelası
- **Toleration**: Pod'un "Ben izin sahibiyim" kartı

### Kullanım Senaryoları

1. **Dedicated Nodes**: Belirli node'ları sadece belirli iş yükleri için ayırma
2. **Special Hardware**: GPU, FPGA gibi özel donanımlı node'lar
3. **Maintenance**: Bakım için node'ları boşaltma
4. **Node Isolation**: Hassas workload'lar için node izolasyonu

### Taint Türleri (Effects)

1. **NoSchedule**: Yeni pod'lar yerleştirilmez (mevcut pod'lar etkilenmez)
2. **PreferNoSchedule**: Mümkünse yerleştirme (soft NoSchedule)
3. **NoExecute**: Yeni pod'lar yerleştirilmez + mevcut pod'lar tahliye edilir

### Mevcut Taint'leri Kontrol Etme

```bash
# Tüm node'ları listele
kubectl get nodes
```

```bash
# Master node'un taint'lerini kontrol et
kubectl describe node kube-master | grep -i taint

# Çıktı örneği (eğer taint'i kaldırmadıysanız):
# Taints: node-role.kubernetes.io/control-plane:NoSchedule
```

```bash
# Worker node'un taint'lerini kontrol et
kubectl describe node kube-worker | grep -i taint

# Çıktı:
# Taints: <none>
```

### Taint Ekleme

**Syntax:**
```bash
kubectl taint nodes <node-name> <key>=<value>:<effect>
```

**Örnek:**
```bash
# Worker node'a taint ekle
kubectl taint nodes kube-worker color=blue:NoSchedule

# Başarılı çıktı:
# node/kube-worker tainted
```

```bash
# Taint'in eklendiğini kontrol et
kubectl describe node kube-worker | grep -i taint

# Çıktı:
# Taints: color=blue:NoSchedule
```

Bu taint şunu söyler: "Bu node'a, `color=blue` taint'ini tolere edemeyen hiçbir pod yerleştirilmesin"

### Test 1: Taint Olmadan Deployment

```bash
# Basit nginx deployment
cat > nginx-deploy.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    environment: dev
spec:
  replicas: 15
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
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF
```

```bash
# Deployment'ı oluştur
kubectl apply -f nginx-deploy.yaml
```

```bash
# Pod'ları kontrol et
kubectl get pods -o wide

# Çıktı: Tüm pod'lar sadece master node'da (worker'da taint var!)
```

```bash
# Bazı pod'lar Pending durumunda olabilir
kubectl get pods | grep Pending

# Detaylı bilgi için
kubectl describe pod <pending-pod-name> | grep -A 5 Events

# Çıktı:
# Warning  FailedScheduling  ... 0/2 nodes are available: 1 node(s) had taint {color: blue}, that the pod didn't tolerate.
```

### Test 2: Toleration Ekleme

`nginx-deploy.yaml` dosyasını güncelleyin:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    environment: dev
spec:
  replicas: 15
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
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
      tolerations:                    # ← Toleration bloğu eklendi
      - key: "color"                  # ← Taint key
        operator: "Equal"             # ← Operatör: Equal veya Exists
        value: "blue"                 # ← Taint value
        effect: "NoSchedule"          # ← Taint effect
```

**Toleration Operatörleri:**

1. **Equal**: Key, value ve effect eşleşmeli
```yaml
tolerations:
- key: "color"
  operator: "Equal"
  value: "blue"
  effect: "NoSchedule"
```

2. **Exists**: Sadece key eşleşmeli (value önemli değil)
```yaml
tolerations:
- key: "color"
  operator: "Exists"
  effect: "NoSchedule"
```

3. **Tüm Taint'leri Tolere Et**:
```yaml
tolerations:
- operator: "Exists"  # Tüm taint'leri tolere et
```

```bash
# Deployment'ı güncelle
kubectl apply -f nginx-deploy.yaml
```

```bash
# Pod'ları kontrol et
kubectl get pods -o wide

# Çıktı: Şimdi pod'lar hem master hem worker node'da çalışıyor
```

```bash
# Bir pod'un toleration'ını kontrol et
kubectl describe pod <pod-name> | grep -A 5 Tolerations

# Çıktı:
# Tolerations:  color=blue:NoSchedule
#               node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
```

### Taint Effect'leri Detaylı

#### 1. NoSchedule

```bash
# NoSchedule taint ekle
kubectl taint nodes kube-worker env=production:NoSchedule

# Davranış:
# - Yeni pod'lar yerleştirilmez
# - Mevcut pod'lar çalışmaya devam eder
```

#### 2. PreferNoSchedule

```bash
# PreferNoSchedule taint ekle
kubectl taint nodes kube-worker env=production:PreferNoSchedule

# Davranış:
# - Scheduler bu node'u tercih etmemeye çalışır
# - Ancak başka seçenek yoksa yine de yerleştirir (soft)
```

#### 3. NoExecute

```bash
# NoExecute taint ekle
kubectl taint nodes kube-worker env=production:NoExecute

# Davranış:
# - Yeni pod'lar yerleştirilmez
# - Mevcut pod'lar TAHLIYE EDİLİR!
# - Toleration'lı pod'lar hariç
```

**NoExecute ile Toleration Süresi:**

```yaml
tolerations:
- key: "env"
  operator: "Equal"
  value: "production"
  effect: "NoExecute"
  tolerationSeconds: 3600  # ← 1 saat tolere et, sonra tahliye et
```

### Gerçek Dünya Örneği: GPU Node

```bash
# GPU node'a taint ekle
kubectl taint nodes gpu-node-1 nvidia.com/gpu=true:NoSchedule

# Sadece GPU ihtiyacı olan pod'lar bu node'u kullanabilir
```

GPU gerektiren pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cuda-pod
spec:
  containers:
  - name: cuda-container
    image: nvidia/cuda:11.0-base
    resources:
      limits:
        nvidia.com/gpu: 1
  tolerations:
  - key: "nvidia.com/gpu"
    operator: "Exists"
    effect: "NoSchedule"
```

### Taint Kaldırma

```bash
# Syntax: kubectl taint nodes <node-name> <key>=<value>:<effect>-
# Son '-' karakteri kaldırma işlemi yapar

# Örnek:
kubectl taint nodes kube-worker color=blue:NoSchedule-

# Başarılı çıktı:
# node/kube-worker untainted
```

```bash
# Tüm taint'leri kontrol et
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, taints: .spec.taints}'
```

```bash
# Temizlik
kubectl delete -f nginx-deploy.yaml
```

### Taint ve Toleration Özeti

| Kavram | Açıklama | Kime Uygulanır |
|--------|----------|----------------|
| **Taint** | Node'u koruma mekanizması | Node'lara |
| **Toleration** | Taint'i tolere etme yeteneği | Pod'lara |
| **NoSchedule** | Yeni pod'ları engelle | Effect |
| **PreferNoSchedule** | Mümkünse engelle | Effect |
| **NoExecute** | Mevcut pod'ları da tahliye et | Effect |

### ⚠️ Önemli Notlar

1. **Taint ≠ Pod Atama**: Taint ve toleration, pod'ları **belirli bir node'a atamaz**, sadece **belirli node'lardan uzak tutar**
   - Pod'u belirli bir node'a atamak için: Node Affinity kullan
   - Pod'u belirli node'lardan uzak tutmak için: Taint + Toleration kullan

2. **Scheduler Esnekliği**: Toleration'lı pod'lar, taint'li node'lara **yerleşebilir** ama **zorunda değildir**
   - Scheduler yine de en uygun node'u seçer

3. **Master Node Koruması**: Production cluster'larda master node'lar her zaman taint'li olmalıdır

4. **Çoklu Taint**: Bir node'a birden fazla taint eklenebilir, pod ise tümünü tolere etmelidir

---

## 🎯 Özet Karşılaştırma Tablosu

| Yöntem | Kullanım Kolaylığı | Esneklik | Kullanım Senaryosu |
|--------|-------------------|----------|-------------------|
| **nodeName** | ⭐ Çok Kolay | ⭐ Çok Düşük | Debug, test |
| **nodeSelector** | ⭐⭐ Kolay | ⭐⭐ Orta | Basit label eşleştirme |
| **Node Affinity (Required)** | ⭐⭐⭐ Orta | ⭐⭐⭐⭐ Yüksek | Karmaşık node seçimi |
| **Node Affinity (Preferred)** | ⭐⭐⭐ Orta | ⭐⭐⭐⭐⭐ Çok Yüksek | Esnek tercihler |
| **Pod Affinity** | ⭐⭐⭐⭐ Zor | ⭐⭐⭐⭐ Yüksek | Pod'ları bir araya getir |
| **Pod Anti-Affinity** | ⭐⭐⭐⭐ Zor | ⭐⭐⭐⭐ Yüksek | Yüksek erişilebilirlik |
| **Taint + Toleration** | ⭐⭐⭐ Orta | ⭐⭐⭐⭐ Yüksek | Node izolasyonu |

---

## 🚀 En İyi Uygulamalar (Best Practices)

### 1. Production Ortamları İçin

```yaml
# Anti-affinity ile yüksek erişilebilirlik
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels:
          app: web
      topologyKey: kubernetes.io/hostname
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
        - key: node-role
          operator: In
          values:
          - worker
```

### 2. Development Ortamları İçin

```yaml
# Basit nodeSelector yeterli
nodeSelector:
  environment: dev
```

### 3. Maliyetli Kaynaklar (GPU, SSD)

```yaml
# Taint ile koru
# kubectl taint nodes gpu-node gpu=true:NoSchedule

# Toleration ile kullan
tolerations:
- key: "gpu"
  operator: "Exists"
  effect: "NoSchedule"
```

### 4. Mikroservis Mimarisi

```yaml
# İletişim kuran servisleri yakın tut
affinity:
  podAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchLabels:
            app: api
        topologyKey: kubernetes.io/hostname
```

---

## 🔧 Troubleshooting

### Pod Pending Durumunda Kalıyor

```bash
# Pod'un olaylarını kontrol et
kubectl describe pod <pod-name>

# Scheduler loglarını kontrol et
kubectl logs -n kube-system <kube-scheduler-pod>
```

**Olası Sebepler:**
- Node'larda yeterli kaynak yok
- Taint tolere edilemiyor
- Node affinity koşulları sağlanmıyor
- Node label'ları yanlış

### Pod'lar Beklenmeyen Node'da

```bash
# Pod'un yerleştirme nedenini gör
kubectl get pod <pod-name> -o yaml | grep -A 20 "nodeName"

# Scheduler kararını detaylı incele
kubectl describe pod <pod-name> | grep -A 10 "Events"
```

### Taint Çalışmıyor

```bash
# Taint'in doğru eklendiğini kontrol et
kubectl get nodes -o json | jq '.items[].spec.taints'

# Pod'un toleration'ını kontrol et
kubectl get pod <pod-name> -o yaml | grep -A 5 tolerations
```

---

## 📚 Ek Kaynaklar

### Kubernetes Resmi Dokümantasyonu

- [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Pod Affinity and Anti-Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)

### Faydalı Komutlar Cheat Sheet

```bash
# Node'ları label'larıyla listele
kubectl get nodes --show-labels

# Belirli label'a sahip node'ları bul
kubectl get nodes -l size=large

# Label ekle
kubectl label nodes <node-name> <key>=<value>

# Label kaldır
kubectl label nodes <node-name> <key>-

# Taint ekle
kubectl taint nodes <node-name> <key>=<value>:<effect>

# Taint kaldır
kubectl taint nodes <node-name> <key>=<value>:<effect>-

# Pod'ları node'larıyla birlikte listele
kubectl get pods -o wide

# Pod'un scheduling bilgilerini detaylı gör
kubectl describe pod <pod-name> | grep -A 20 "Node-Selectors\|Tolerations\|Affinity"

# Deployment'ı yeniden başlat (pod'ları yeniden schedule et)
kubectl rollout restart deployment <deployment-name>
```

---

## ✅ Tamamlama Kontrol Listesi

Bu eğitimi tamamladıktan sonra aşağıdaki konularda yetkin olmalısınız:

- [ ] Kubernetes scheduler'ın nasıl çalıştığını anlıyorum
- [ ] nodeName kullanarak pod'ları belirli node'lara atayabiliyorum
- [ ] Node'lara label ekleyip nodeSelector ile kullanabiliyorum
- [ ] Node Affinity ile karmaşık scheduling kuralları yazabiliyorum
- [ ] Required ve Preferred affinity arasındaki farkı biliyorum
- [ ] Pod Affinity ile pod'ları bir araya getirebiliyorum
- [ ] Pod Anti-Affinity ile pod'ları dağıtabiliyorum
- [ ] Taint ve Toleration kullanarak node'ları koruyabiliyorum
- [ ] Production senaryoları için uygun scheduling stratejisi seçebiliyorum

---

## 🎓 İleri Seviye Konular

Bu eğitimi tamamladıktan sonra aşağıdaki konulara geçebilirsiniz:

1. **Custom Schedulers**: Kendi scheduler'ınızı yazma
2. **Scheduler Profiles**: Farklı workload'lar için farklı scheduling davranışları
3. **Descheduler**: Pod'ları runtime'da yeniden schedule etme
4. **Pod Priority and Preemption**: Pod'lara öncelik verme
5. **Resource Quotas**: Namespace bazlı kaynak sınırları
6. **Cluster Autoscaler**: Node'ları otomatik ölçeklendirme

---

**Hazırlayan:** Kubernetes Eğitim Ekibi  
**Son Güncelleme:** Mart 2026  
**Kubernetes Versiyonu:** v1.30.x

Bu eğitimde sorular veya geri bildirimler için lütfen iletişime geçin. İyi çalışmalar! 🚀
