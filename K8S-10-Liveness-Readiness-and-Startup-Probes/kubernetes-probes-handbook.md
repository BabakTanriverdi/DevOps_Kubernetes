# Kubernetes-09: Liveness, Readiness ve Startup Probes — Kapsamlı Rehber

> **Hedef Kitle:** Kubernetes'e aşina, pod yaşam döngüsünü derinlemesine öğrenmek isteyen DevOps/Platform mühendisleri.  
> **Kubernetes Sürümü:** 1.27+ uyumlu  
> **Tahmini Süre:** ~90 dakika

---

## İçindekiler

1. [Temel Kavramlar — Neden Probe'lara İhtiyaç Duyarız?](#1-temel-kavramlar)
2. [Ortam Kurulumu](#2-ortam-kurulumu)
3. [livenessProbe — Canlılık Kontrolü](#3-livenessprobe)
   - 3.1 HTTP GET Probe
   - 3.2 Exec (Komut) Probe
   - 3.3 TCP Socket Probe
4. [startupProbe — Başlangıç Kontrolü](#4-startupprobe)
5. [readinessProbe — Hazırlık Kontrolü](#5-readinessprobe)
6. [Probe Parametreleri — Tam Referans](#6-probe-parametreleri)
7. [Probe'ların Birlikte Kullanımı — Best Practices](#7-birlikte-kullanim)
8. [Sorun Giderme Rehberi](#8-sorun-giderme)
9. [Kaynaklar](#9-kaynaklar)

---

## 1. Temel Kavramlar

### Kubernetes Neden Probe'lara İhtiyaç Duyar?

Bir container'ın **çalışıyor** olması, uygulamanın **sağlıklı** olduğu anlamına gelmez. Şu senaryoları düşünelim:

| Senaryo | Sorun | Çözüm |
|---|---|---|
| Uygulama deadlock'a girdi, process devam ediyor | Traffic alıyor ama yanıt veremiyor | `livenessProbe` → container restart |
| Uygulama henüz başlamadı, DB bağlantısı kuruluyor | İstek gelirse 500 döner | `readinessProbe` → endpoint'ten çıkar |
| Legacy uygulama 2 dakikada ayağa kalkıyor | liveness probe çok erken başarısız sayar | `startupProbe` → liveness'ı geciktir |

### Probe Akış Diyagramı

```
Container Başlar
      │
      ▼
[startupProbe var mı?]
      │ EVET                       HAYIR
      ▼                              │
startupProbe çalışır ◄───────────────┘
(başarıyla tamamlanana kadar
 liveness & readiness DURDURULUR)
      │ BAŞARILI
      ▼
[livenessProbe] ──── BAŞARISIZ ──► Container yeniden başlatılır
      │ BAŞARILI
      ▼
[readinessProbe] ─── BAŞARISIZ ──► Pod Service endpoint'inden çıkarılır
      │ BAŞARILI
      ▼
Traffic alır ✓
```

### Probe Türleri

Kubernetes üç farklı probe mekanizmasını destekler:

- **`httpGet`** — Belirtilen path'e HTTP GET isteği gönderir; 200-399 arası HTTP status kodu başarı sayılır.
- **`exec`** — Container içinde bir komut çalıştırır; exit code `0` başarı sayılır.
- **`tcpSocket`** — Belirtilen porta TCP bağlantısı açmayı dener; bağlantı kurulabiliyorsa başarı sayılır.
- **`grpc`** *(Kubernetes 1.24+ GA)* — gRPC Health Checking protokolünü kullanır.

---

## 2. Ortam Kurulumu

### Cluster'ı Başlatmak

İki node'lu (1 master, 1 worker) Ubuntu 20.04 üzerinde bir Kubernetes cluster'ı başlatın.

> 💡 **İpucu:** Yerel ortam yoksa [Killercoda Playground](https://killercoda.com/playgrounds) ücretsiz tarayıcı tabanlı Kubernetes ortamı sağlar.

```bash
# Cluster durumunu doğrula
kubectl cluster-info

# Node'ların Ready durumda olduğunu kontrol et
kubectl get nodes -o wide
```

Beklenen çıktı:
```
NAME           STATUS   ROLES           AGE   VERSION
controlplane   Ready    control-plane   5m    v1.27.0
node01         Ready    <none>          4m    v1.27.0
```

---

## 3. livenessProbe

> **Tanım:** Kubelet, livenessProbe kullanarak container'ın hâlâ sağlıklı çalışıp çalışmadığını periyodik olarak kontrol eder. Probe başarısız olursa kubelet container'ı yeniden başlatır. Deadlock, sonsuz döngü veya "yanıt vermez ama process durmuş değil" gibi durumları yakalamak için idealdir.

### 3.1 HTTP GET Probe

#### Senaryo

Uygulama ilk 30 saniye sağlıklı (`200 OK`), sonrasında bozuk (`500`) davranmaktadır. Kubelet 30 saniyeden sonra container'ı yeniden başlatmalıdır.

#### Uygulama Kodu (clarusway/probes)

```python
from flask import Flask, Response
import time

app = Flask(__name__)
start = time.time()

@app.route("/healthz")
def health_check():
    elapsed = time.time() - start
    if elapsed < 30:
        return Response("{'status':'healthy'}", status=200, mimetype='application/json')
    # 30 saniye sonra hiçbir şey döndürülmüyor → implicit None → 500
    # Gerçek uygulamalarda explicit 500 dönebilir
    return Response("{'status':'unhealthy'}", status=500, mimetype='application/json')

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=80)
```

#### Manifest: `http-liveness.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-http
spec:
  containers:
  - name: liveness
    image: clarusway/probes
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /healthz      # Sağlık endpoint'i
        port: 80
        # İsteğe bağlı: özel header eklenebilir
        # httpHeaders:
        # - name: Custom-Header
        #   value: Awesome
      initialDelaySeconds: 3   # İlk probe öncesi bekleme süresi
      periodSeconds: 3          # Probe aralığı
      timeoutSeconds: 1         # Probe timeout süresi (varsayılan: 1s)
      failureThreshold: 3       # Kaç başarısızlık sonrası restart? (varsayılan: 3)
      successThreshold: 1       # Kaç başarı sonrası "sağlıklı"? (varsayılan: 1)
---
apiVersion: v1
kind: Service
metadata:
  name: liveness-svc
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30001
  selector:
    test: liveness
```

#### Uygulama ve Gözlemleme

```bash
# Pod ve Service'i oluştur
kubectl apply -f http-liveness.yaml

# Pod durumunu izle (RESTARTS sayısını takip et)
watch kubectl get pod liveness-http

# İlk 30 saniye: RESTARTS = 0 (probe başarılı)
# 30+ saniye: RESTARTS artmaya başlar (probe başarısız → restart)

# Detaylı olay akışını gör
kubectl describe pod liveness-http
# "Liveness probe failed: HTTP probe failed with statuscode: 500" mesajını arayın
# "Killing container with id...: Container failed liveness probe" mesajını arayın

# Temizlik
kubectl delete -f http-liveness.yaml
```

> ⚠️ **Dikkat:** `initialDelaySeconds` değeri uygulamanın başlama süresinden kısa tutulursa, uygulama ayağa kalkmadan probe başarısız sayılır ve container sonsuz döngüde restart atar. Başlama süresi değişken/uzunsa `startupProbe` tercih edin.

---

### 3.2 Exec (Komut) Probe

#### Senaryo

Container başladığında `/tmp/healthy` dosyası oluşturulur; 30 saniye sonra silinir. Probe bu dosyanın varlığını kontrol eder.

#### Manifest: `liveness-exec.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-exec
spec:
  containers:
  - name: liveness
    image: clarusway/probes
    # Container başladığında çalışacak komut dizisi:
    # 1. /tmp/healthy dosyasını oluştur
    # 2. 30 saniye bekle
    # 3. Dosyayı sil (probe artık başarısız olacak)
    # 4. 600 saniye bekle (container çalışmaya devam etsin)
    args:
    - /bin/sh
    - -c
    - "touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600"
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy      # Dosya varsa exit 0, yoksa exit 1
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 3
```

#### Uygulama ve Gözlemleme

```bash
kubectl apply -f liveness-exec.yaml

# Canlı izleme
watch kubectl get pod liveness-exec

# İlk 30 saniye: /tmp/healthy var → cat başarılı → probe OK
# 30-45 saniye (3 başarısız probe × 5s): restart tetiklenir

kubectl describe pod liveness-exec
# "cat: /tmp/healthy: No such file or directory" mesajını arayın

# Temizlik
kubectl delete -f liveness-exec.yaml
```

> 💡 **Gerçek Dünya Kullanımı:** Exec probe'lar özellikle HTTP endpoint'i olmayan uygulamalarda (batch job, sidecar container, vb.) veya daha karmaşık sağlık kontrolleri gerektiren durumlarda kullanışlıdır. Örneğin bir veritabanı container'ı için `pg_isready` komutu çalıştırılabilir.

---

### 3.3 TCP Socket Probe

#### Senaryo

MySQL container'ı üzerinde TCP port erişilebilirliği kontrol edilir. Önce yanlış port (8080) ile test yapılır, ardından doğru port (3306) ile düzeltilir.

#### Manifest: `tcp-liveness.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-tcp
spec:
  containers:
  - name: liveness-tcp
    image: mysql:8.0
    ports:
    - containerPort: 3306
    env:
    - name: MYSQL_ROOT_PASSWORD
      value: "SecurePass123!"   # Üretimde Secret kullanın!
    livenessProbe:
      tcpSocket:
        port: 8080              # ❌ Yanlış port — probe başarısız olacak
      initialDelaySeconds: 15   # MySQL'in başlaması için süre tanı
      periodSeconds: 20
      failureThreshold: 3
```

#### Adım 1 — Hatalı Konfigürasyonla Test

```bash
kubectl apply -f tcp-liveness.yaml

# 15 saniye sonra probe başlar, 8080 kapalı → başarısız
kubectl describe pod liveness-tcp
# "Liveness probe failed: dial tcp ... connection refused" mesajını arayın

watch kubectl get pod liveness-tcp
# RESTARTS sayısının arttığını gözlemleyin
```

#### Adım 2 — Portu Düzelt ve Yeniden Test

`tcp-liveness.yaml` dosyasını açıp şu satırı değiştirin:

```yaml
# ESKİ:
port: 8080

# YENİ:
port: 3306
```

```bash
kubectl delete -f tcp-liveness.yaml
kubectl apply -f tcp-liveness.yaml

# 15 saniye sonra MySQL portu erişilebilir → probe başarılı
kubectl describe pod liveness-tcp
# "Liveness probe succeeded" mesajını arayın

watch kubectl get pod liveness-tcp
# RESTARTS = 0 kalmalı

# Temizlik
kubectl delete -f tcp-liveness.yaml
```

> 💡 **TCP vs HTTP Probe:** TCP probe sadece "port açık mı?" sorusunu yanıtlar; uygulamanın o portta doğru yanıt verip vermediğini kontrol etmez. Mümkün olan her durumda HTTP probe tercih edin.

---

## 4. startupProbe

> **Tanım:** Kubelet, startupProbe ile container uygulamasının başlatılıp başlatılmadığını belirler. startupProbe **başarılı olana kadar** livenessProbe ve readinessProbe **devre dışı kalır**. Bu, yavaş başlayan uygulamaların haksız yere restart edilmesini önler.

### Ne Zaman Kullanılır?

- Başlama süresi **değişken veya uzun** olan uygulamalar (örn. büyük Java uygulamaları, legacy monolitler)
- Başlangıçta veritabanı migration, önbellek yükleme gibi ağır işlemler yapan servisler
- `initialDelaySeconds` ile yeterince karşılanamayan durumlar

### Senaryo

Uygulama ilk 60 saniye `500` döndürür, sonrasında `200` döndürür. startupProbe `5 × 15s = 75 saniye` fırsat tanır.

#### Uygulama Kodu (clarusway/startupprobe)

```python
from flask import Flask, Response
import time

app = Flask(__name__)
start = time.time()

@app.route('/')
def home():
    return "Welcome to Clarusway Kubernetes Lesson"

@app.route("/healthz")
def health_check():
    elapsed = time.time() - start
    if elapsed > 60:
        return Response("{'status':'ready'}", status=200, mimetype='application/json')
    # 60 saniyeden önce başarısız
    return Response("{'status':'starting'}", status=500, mimetype='application/json')

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=80)
```

#### Manifest: `startup.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: startup
  name: startup-http
spec:
  containers:
  - name: liveness
    image: clarusway/startupprobe
    ports:
    - containerPort: 80
    # startupProbe başarıya ulaşana kadar bu probe ÇALIŞMAZ
    livenessProbe:
      httpGet:
        path: /healthz
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 3
      failureThreshold: 3
    # Uygulama 60s içinde hazır olmayabilir
    # failureThreshold × periodSeconds = 5 × 15 = 75s maksimum bekleme
    startupProbe:
      httpGet:
        path: /healthz
        port: 80
      failureThreshold: 5     # 5 başarısızlığa kadar tahammül
      periodSeconds: 15       # Her 15 saniyede bir kontrol
      # 75 saniye içinde bir kez başarılı olursa → liveness devreye girer
---
apiVersion: v1
kind: Service
metadata:
  name: startup-svc
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30001
  selector:
    test: startup
```

#### Zaman Çizelgesi

```
t=0s   : Container başlar, startupProbe aktif
t=15s  : 1. startupProbe → 500 (başarısız, failureCount=1)
t=30s  : 2. startupProbe → 500 (başarısız, failureCount=2)
t=45s  : 3. startupProbe → 500 (başarısız, failureCount=3)
t=60s  : Uygulama hazır, /healthz → 200 dönmeye başlar
t=60s  : 4. startupProbe → 200 ✓ BAŞARILI
         → livenessProbe devreye girer
t=63s  : 1. livenessProbe → 200 ✓
t=75s  : startupProbe hiç başarılı olmasa → container kill (restartPolicy'e göre)
```

#### Uygulama ve Gözlemleme

```bash
kubectl apply -f startup.yaml

# startupProbe devreye giriyor, liveness henüz aktif değil
kubectl get pod startup-http

# Olayları canlı izle
kubectl describe pod startup-http
# "Startup probe failed" mesajlarını gördükten sonra
# "Container is ready" mesajını bekleyin

watch kubectl get pod startup-http

# Temizlik
kubectl delete -f startup.yaml
```

> ⚠️ **Kritik Not:** `failureThreshold × periodSeconds` değeri uygulamanın **en kötü senaryodaki** başlangıç süresinden büyük olmalıdır. Küçük tutulursa uygulama hazır olmadan restart atar.

---

## 5. readinessProbe

> **Tanım:** Kubelet, readinessProbe ile container'ın trafik almaya hazır olup olmadığını belirler. **Tüm container'ları hazır olan Pod'lar** Service'in endpoint listesine eklenir; hazır olmayanlar çıkarılır. Container **restart edilmez**, sadece trafik yönlendirilmez.

### livenessProbe ile Farkı

| Özellik | livenessProbe | readinessProbe |
|---|---|---|
| Başarısız olunca ne olur? | Container restart | Pod Service endpoint'inden çıkarılır |
| Container hayatta mı kalır? | Hayır (restart) | Evet |
| Ne zaman kullanılır? | Deadlock, donma | Geçici hazır olmama durumu |
| Tam yaşam döngüsü boyunca çalışır mı? | Evet | Evet |

### Senaryo

3 replikalı Deployment; her Pod ilk 45 saniye `500` döndürür. readinessProbe bu süre zarfında Pod'ları endpoint dışında tutar.

#### Uygulama Kodu (clarusway/readinessprobe)

```python
from flask import Flask, Response
import time

app = Flask(__name__)
start = time.time()

@app.route('/')
def home():
    return "Welcome to Clarusway Kubernetes Lesson"

@app.route("/healthz")
def health_check():
    elapsed = time.time() - start
    if elapsed > 45:
        return Response("{'status':'ready'}", status=200, mimetype='application/json')
    return Response("{'status':'not_ready'}", status=500, mimetype='application/json')

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=80)
```

#### Manifest: `http-readiness.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: readiness
spec:
  replicas: 3
  selector:
    matchLabels:
      test: readiness
  template:
    metadata:
      labels:
        test: readiness
    spec:
      containers:
      - name: readiness
        image: clarusway/readinessprobe
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 3    # İlk probe öncesi bekleme
          periodSeconds: 3          # Her 3 saniyede bir kontrol
          successThreshold: 10      # 10 ardışık başarı → "hazır"
          failureThreshold: 5       # 5 ardışık başarısızlık → "hazır değil"
          timeoutSeconds: 2         # Her probe için timeout
---
apiVersion: v1
kind: Service
metadata:
  name: readiness-http
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30001
  selector:
    test: readiness
```

> 💡 **`successThreshold: 10` Neden?** Bu değer, Pod'un endpoint'e eklenmesi için 10 × 3s = 30 saniye boyunca sağlıklı kalmasını zorunlu kılar. Sık sık unstable olan uygulamalarda "erken endpoint eklenmesi"ni önlemek için kullanışlıdır. Varsayılan değer 1'dir.

#### Uygulama ve Adım Adım Gözlemleme

```bash
# Deployment ve Service'i oluştur
kubectl apply -f http-readiness.yaml

# --- İlk 45 saniyede ---
# Pod'lar Running ama READY değil (0/1)
kubectl get deployment readiness
kubectl get pods -l test=readiness

# Endpoint'te hiç adres yok → Service trafik yönlendiremiyor
kubectl get endpoints readiness-http
# NotReadyAddresses alanında Pod IP'leri görünür
kubectl describe endpoints readiness-http

# --- 45 saniye sonra ---
# readinessProbe başarılı olmaya başlar
# successThreshold=10 nedeniyle 45+30=75. saniyede endpoint'e girer
watch kubectl get pods -l test=readiness
# READY sütunu 0/1 → 1/1 değişmeli

# --- Pod silme testi ---
# Bir Pod'u sil ve endpoint değişimini gözlemle
POD_NAME=$(kubectl get pod -l test=readiness -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD_NAME

# Yeni Pod oluşur ama hazır olana kadar endpoint'e girmez
watch kubectl get pods -l test=readiness
kubectl describe endpoints readiness-http
# Silinen Pod'un IP'si NotReadyAddresses'a düşer

# Temizlik
kubectl delete -f http-readiness.yaml
```

---

## 6. Probe Parametreleri — Tam Referans

Tüm probe türlerinde kullanılabilen ortak parametreler:

| Parametre | Varsayılan | Açıklama |
|---|---|---|
| `initialDelaySeconds` | 0 | Container başladıktan kaç saniye sonra ilk probe başlasın |
| `periodSeconds` | 10 | Probeler arası bekleme süresi (saniye). Minimum: 1 |
| `timeoutSeconds` | 1 | Probe'un zaman aşımı süresi. Minimum: 1 |
| `successThreshold` | 1 | "Sağlıklı" sayılmak için gereken ardışık başarı sayısı |
| `failureThreshold` | 3 | "Başarısız" sayılmak için gereken ardışık başarısızlık sayısı |

`startupProbe` özelinde:

| Parametre | Açıklama |
|---|---|
| `failureThreshold` | `failureThreshold × periodSeconds` = maksimum bekleme süresi |

---

## 7. Birlikte Kullanım — Best Practices

### Üç Probe'u Birlikte Kullanan Gerçekçi Örnek

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: production-app
spec:
  containers:
  - name: app
    image: myapp:1.0
    ports:
    - containerPort: 8080
    # 1. startupProbe: Uygulama başlayana kadar diğerlerini beklet
    startupProbe:
      httpGet:
        path: /health/startup
        port: 8080
      failureThreshold: 30      # 30 × 10s = 300s (5 dakika) startup fırsatı
      periodSeconds: 10
    # 2. livenessProbe: Deadlock veya donma durumunu yakala → restart
    livenessProbe:
      httpGet:
        path: /health/live
        port: 8080
      initialDelaySeconds: 0    # startupProbe başarılı sonrası hemen başlar
      periodSeconds: 10
      timeoutSeconds: 3
      failureThreshold: 3       # 30 saniye yanıt gelmezse restart
    # 3. readinessProbe: Geçici hazır olmama durumunda trafiği kes
    readinessProbe:
      httpGet:
        path: /health/ready
        port: 8080
      initialDelaySeconds: 0
      periodSeconds: 5
      timeoutSeconds: 2
      successThreshold: 1
      failureThreshold: 3       # 15 saniye yanıt gelmezse endpoint'ten çıkar
```

### Endpoint Ayrımı (Best Practice)

Üretim uygulamalarında her probe için **ayrı endpoint** kullanmak önerilir:

| Endpoint | Kontrol Ettiği | Örnek |
|---|---|---|
| `/health/startup` | Uygulama en temel başlangıcını tamamladı mı? | Port açık mı? |
| `/health/live` | Uygulama yanıt verebiliyor mu? | Deadlock yok mu? |
| `/health/ready` | İstek işleyebilir durumda mı? | DB bağlantısı var mı? |

### Genel Öneriler

- **Probe'ları hafif tutun.** Probe'lar sürekli çalıştığından ağır işlemler (DB query, ağır hesaplama) cluster genelinde ciddi yük oluşturabilir.
- **`livenessProbe`'u agresif yapmayın.** Çok düşük `failureThreshold` geçici ağ aksaklıklarında gereksiz restart'a yol açar.
- **readinessProbe'u livenessProbe'dan bağımsız düşünün.** readiness başarısız olduğunda liveness çalışmaya devam eder.
- **Üretimde her zaman üç probe'u da tanımlayın.** Tanımlanmayan probe default olarak "başarılı" kabul edilir, bu da risktir.
- **`successThreshold` livenessProbe için her zaman 1 olmalıdır.** Kubernetes bu değeri 1 dışında kabul etmez.

---

## 8. Sorun Giderme Rehberi

### Sık Karşılaşılan Problemler

**Problem: Pod sürekli CrashLoopBackOff durumunda**
```bash
# Nedeni bul
kubectl describe pod <pod-name>
# "Liveness probe failed" veya "Startup probe failed" mesajını ara
kubectl logs <pod-name> --previous   # Önceki container'ın logları
```

**Problem: Pod Running ama Service'ten trafik gelmiyor**
```bash
# Readiness durumunu kontrol et
kubectl get pod <pod-name>           # READY sütunu 0/1 mi?
kubectl describe pod <pod-name>      # "Readiness probe failed" var mı?
kubectl describe endpoints <svc>     # NotReadyAddresses dolu mu?
```

**Problem: Probe'lar sürekli timeout alıyor**
```bash
# timeoutSeconds artır veya uygulamayı optimize et
# Probe'un ağ yolunu kontrol et (NetworkPolicy, firewall)
kubectl exec -it <pod-name> -- curl -v http://localhost:<port>/healthz
```

**Problem: İlk deploy'da tüm Pod'lar aynı anda hazır değil**
```bash
# Bu normaldir — readinessProbe beklenen davranış
# Deployment strategy'yi kontrol et
kubectl describe deployment <name>
# maxUnavailable ve maxSurge değerlerini ayarla
```

### Faydalı Komutlar

```bash
# Tüm Pod'ların probe durumlarını özetle
kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
READY:.status.containerStatuses[0].ready,\
RESTARTS:.status.containerStatuses[0].restartCount,\
STATE:.status.phase

# Bir Pod'un probe konfigürasyonunu görüntüle
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[0].livenessProbe}' | python3 -m json.tool

# Endpoint değişimlerini canlı izle
watch -n 2 kubectl describe endpoints <service-name>
```

---

## 9. Kaynaklar

- [Kubernetes Resmi Dokümantasyon — Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Kubernetes API Reference — Probe v1 core](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#Probe)
- [Production Best Practices for Kubernetes](https://learnk8s.io/production-best-practices)

---

*Son güncelleme: Kubernetes 1.27 · Hazırlayan: Clarusway DevOps Bootcamp*
