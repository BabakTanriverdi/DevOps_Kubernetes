# Hands-on Kubernetes-05: Secrets ve ConfigMaps Yönetimi

## Amaç

Bu uygulamalı eğitim, Kubernetes Secrets ve ConfigMaps kullanarak güvenli yapılandırma yönetimi konusunda pratik bilgi sağlar.

## Öğrenme Çıktıları

Bu eğitimin sonunda şunları yapabileceksiniz:

- Kubernetes Secrets'ı anlama ve açıklama
- Secrets kullanarak hassas verileri (password'ler, token'lar, key'ler) güvenli bir şekilde paylaşma
- ConfigMaps kullanarak Kubernetes'te uygulama yapılandırması yönetme

## İçerik

- **Bölüm 1** - Kubernetes Cluster Kurulumu
- **Bölüm 2** - Kubernetes Secrets
- **Bölüm 3** - Kubernetes'te ConfigMaps

---

## Bölüm 1 - Kubernetes Cluster Kurulumu

### Cluster Kurulumu

Ubuntu 22.04 üzerinde iki node'lu (bir master, bir worker) bir Kubernetes Cluster başlatın. [Cloudformation Template to Create Kubernetes Cluster](../S2-kubernetes-02-basic-operations/cfn-template-to-create-k8s-cluster.yml) kullanabilirsiniz.

> **Not:** Master node hazır olduğunda, worker node otomatik olarak cluster'a katılır.

> **Alternatif:** Kubernetes cluster ile ilgili sorun yaşarsanız playground'u kullanabilirsiniz: https://killercoda.com/playgrounds

### Kurulumu Doğrulama

Kubernetes'in çalıştığını ve node'ların hazır olduğunu kontrol edin:

```bash
kubectl cluster-info
kubectl get no
```

---

## Bölüm 2 - Kubernetes Secrets

### kubectl Kullanarak Secret Oluşturma

Secret'lar, Pod'ların veritabanlarına veya servislere erişmek için ihtiyaç duyduğu hassas kullanıcı kimlik bilgilerini içerir. Örneğin, bir veritabanı bağlantısı kullanıcı adı ve şifre gerektirir.

#### Kimlik Bilgisi Dosyaları Oluşturma

```bash
# Örnek için dosyalar oluştur
echo -n 'admin' > ./username.txt
echo -n '1f2d1e2e67df' > ./password.txt
```

> **Not:** `-n` flag'i satır sonu karakterinin çıktıda yer almamasını sağlar.

#### Dosyalardan Secret Oluşturma

`kubectl create secret` komutu dosyaları bir Secret object'ine paketler:

```bash
kubectl create secret generic --help
kubectl create secret generic db-user-pass --from-file=./username.txt --from-file=./password.txt
```

**Çıktı:**
```bash
secret/db-user-pass created
```

#### Özel Key İsimleri Kullanma

Dosya adları yerine özel key isimleri belirleyebilirsiniz:

```bash
kubectl create secret generic db-user-pass-key \
  --from-file=username=./username.txt \
  --from-file=password=./password.txt
```

#### Dizinden Secret Oluşturma

```bash
kubectl create secret generic my-secret --from-file=/home/ubuntu/Lesson
```

#### Secret'larda Özel Karakterler

> **Önemli:** `$`, `\`, `*`, `=` ve `!` gibi özel karakterler escape edilmelidir. En kolay yol tek tırnak kullanmaktır:

```bash
kubectl create secret generic dev-db-secret \
  --from-literal=username=devuser \
  --from-literal=password='S!B\*d$zDsb='
```

> **Not:** `--from-file` kullandığınızda özel karakterleri escape etmeniz gerekmez.

### Secret'ları Görüntüleme

#### Secret'ları Listeleme

```bash
kubectl get secrets
```

**Çıktı:**
```bash
NAME                  TYPE                                  DATA      AGE
db-user-pass          Opaque                                2         51s
```

#### Secret Detayları

```bash
kubectl describe secrets/db-user-pass
kubectl get secrets/db-user-pass -o yaml
```

> **Not:** `kubectl get` ve `kubectl describe` komutları varsayılan olarak secret içeriklerini hassas verileri korumak için göstermez.

**Çıktı:**
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

### Manuel Secret Oluşturma

YAML veya JSON manifest'ler kullanarak Secret oluşturabilirsiniz. Secret object'inin iki field'ı vardır: `data` (base64-encoded) ve `stringData` (düz metin, otomatik encode edilir).

#### Değerleri Base64'e Encode Etme

```bash
echo -n 'admin' | base64
# Çıktı: YWRtaW4=

echo -n '1f2d1e2e67df' | base64
# Çıktı: MWYyZDFlMmU2N2Rm
```

#### Base64 Değerlerini Decode Etme

```bash
echo 'YWRtaW4=' | base64 -d
# Çıktı: admin
```

> **Önemli:** Base64 encoding'de satır sonu karakteri olmaması için `-n` flag'i kritiktir.

#### Secret YAML Dosyası Oluşturma

`secret.yaml` oluşturun:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  username: YWRtaW4=              # base64 encoded 'admin'
  password: MWYyZDFlMmU2N2Rm      # base64 encoded '1f2d1e2e67df'
# stringData kullanarak alternatif (otomatik encode edilir):
# stringData:
#   username: admin
#   password: '1f2d1e2e67df'
```

**Referans:** [Kubernetes Secret API Dokümantasyonu](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/secret-v1/)

#### Secret'ı Uygulama

```bash
kubectl apply -f ./secret.yaml
```

**Çıktı:**
```bash
secret/mysecret created
```

---

### Secret'ı Decode Etme

Secret'ları görüntüleme:

```bash
kubectl get secret mysecret -o yaml
```

**Çıktı:**
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

#### Password Field'ını Decode Etme

```bash
echo 'MWYyZDFlMmU2N2Rm' | base64 --decode
# Çıktı: 1f2d1e2e67df
```

---

### Pod'larda Secret Kullanımı

#### Yöntem 1: Düz Environment Variable'lar (Önerilmez)

`mysecret-pod.yaml` oluşturun:

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

Pod'u oluştur ve test et:

```bash
kubectl apply -f mysecret-pod.yaml
kubectl exec -it secret-env-pod -- bash
echo $SECRET_USERNAME
echo $SECRET_PASSWORD
exit
```

Pod'u sil:

```bash
kubectl delete -f mysecret-pod.yaml
```

#### Yöntem 2: Secret'lardan Environment Variable'lar (Önerilen)

`mysecret-pod.yaml`'ı güncelleyin:

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

Güncellenmiş pod'u uygula:

```bash
kubectl apply -f mysecret-pod.yaml
```

### Environment Variable'lardan Secret Değerlerini Kullanma

Container içinde, secret key'leri base64-decoded değerlerle normal environment variable'lar olarak görünür:

```bash
kubectl exec -it secret-env-pod -- bash
echo $SECRET_USERNAME    # Çıktı: admin
echo $SECRET_PASSWORD    # Çıktı: 1f2d1e2e67df
env                      # Tüm environment variable'ları görüntüle
exit
```

---

## Bölüm 3 - Kubernetes'te ConfigMaps

### ConfigMap Nedir?

ConfigMap'ler, yapılandırmayı container image'larından ayırmanıza olanak tanır ve uygulamaları daha taşınabilir hale getirir. Secret'ların aksine, ConfigMap'ler hassas olmayan yapılandırma verileri için tasarlanmıştır.

### ConfigMap Oluşturma

#### Yöntem 1: Literal Değerlerden

```bash
kubectl create configmap demo-config --from-literal=greeting=Hola
```

#### Yöntem 2: YAML Dosyasından

`configmap.yaml` oluşturun:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: demo-config
data:
  greeting: Hola
```

ConfigMap'i uygulayın:

```bash
kubectl apply -f configmap.yaml
```

### ConfigMap'i Doğrulama

```bash
kubectl get configmap
kubectl describe configmap demo-config
kubectl get configmap demo-config -o yaml
```

---

### Uygulamalarda ConfigMap Kullanımı

#### Uygulama Kurulumu

Dizin yapısı oluşturun:

```bash
mkdir k8s
cd k8s
```

#### Deployment Oluşturma

`k8s/deployment.yaml` oluşturun:

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

#### Service Oluşturma

`k8s/service.yaml` oluşturun:

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

#### Deploy ve Test

```bash
kubectl apply -f k8s/

kubectl get svc
# Çıktı:
# NAME           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
# demo-service   NodePort    10.102.145.186   <none>        80:30001/TCP   5s

curl <worker-ip>:30001
# Çıktı: Hola, Clarusway!
```

#### Temizlik

```bash
kubectl delete -f k8s
```

---

### Tüm ConfigMap Key'lerini Environment Variable Olarak Kullanma

Tek tek key mapping yapmak yerine, `envFrom` kullanarak tüm ConfigMap verisini bir kerede inject edebilirsiniz.

#### ConfigMap'i Güncelleme

`configmap.yaml`'ı değiştirin:

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

#### Deployment'ı Güncelleme

`deployment.yaml`'ı değiştirin:

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

> **Önemli Değişiklik:** `env` yerine `envFrom` kullanmak tüm ConfigMap key'lerini environment variable olarak inject eder.

#### Uygulama ve Test

```bash
kubectl apply -f k8s/

kubectl get svc
curl <worker-ip>:30001
# Çıktı: Hallo, Clarusway!
```

#### Environment Variable'ları Doğrulama

```bash
kubectl get po
kubectl exec -it <pod-name> -- sh
env
exit
```

Tüm ConfigMap key'leri artık container içinde environment variable olarak mevcut.

```bash
kubectl delete -f k8s
```

---

### Dosyalardan ConfigMap

#### İçerik Dosyası Oluşturma

```bash
echo "Welcome to the Kubernetes Lessons." > content
```

#### Dosyadan ConfigMap Oluşturma

```bash
kubectl create configmap nginx-config --from-file=./content
```

#### ConfigMap'i Görüntüleme

```bash
kubectl get configmap/nginx-config -o yaml
```

**Çıktı:**
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

### ConfigMap'leri Volume Olarak Kullanma

Volume'ler, yapılandırma dosyalarını container'lara mount etmenin yaygın bir yoludur.

#### Nginx Deployment Oluşturma

`nginx-deployment.yaml` oluşturun:

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

Bu yapılandırma:
- `nginx-config` ConfigMap'inden `content` key'ini seçer
- Container içinde `/usr/share/nginx/html/` dizinine mount eder
- Dosyayı `index.html` olarak adlandırır

Deployment'ı uygulayın:

```bash
kubectl apply -f nginx-deployment.yaml
```

#### Nginx Service Oluşturma

`nginx-service.yaml` oluşturun:

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

Service'i uygulayın:

```bash
kubectl apply -f nginx-service.yaml
```

#### Uygulamayı Test Etme

```bash
curl <worker-ip>:30002
# Çıktı: Welcome to the Kubernetes Lessons.
```

#### Temizlik

```bash
kubectl delete -f nginx-service.yaml
kubectl delete -f nginx-deployment.yaml
```

---

### Opsiyonel: Secret'ları Volume Olarak Kullanma

#### Secret Oluşturma

```bash
kubectl create secret generic nginx-secret \
  --from-literal=username=devuser \
  --from-literal=password='devpassword'
```

#### Secret'ı Görüntüleme

```bash
kubectl get secret nginx-secret -o yaml
```

#### Nginx Deployment'ı Secret Volume ile Güncelleme

`nginx-deployment.yaml`'ı güncelleyin:

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

Değişiklikleri uygulayın:

```bash
kubectl apply -f nginx-deployment.yaml
```

#### Secret Dosyalarını Doğrulama

```bash
kubectl get pod
kubectl exec -it <nginx-pod-name> -- bash
cd /test
ls              # Gösterir: password  username
cat password    # Gösterir: devpassword
cat username    # Gösterir: devuser
exit
```

> **Not:** `/test` klasöründeki dosya isimleri `nginx-secret`'tan gelen key'lerdir ve dosya içerikleri karşılık gelen değerlerdir.

---

## Challenge (Opsiyonel)

Clarusway repository'sindeki Hello app'ini kullanın ve `$GREETINGS` environment variable'ını ConfigMaps yerine Secrets kullanarak yapılandırın.

---

## Ek Kaynaklar

### Kubernetes Dokümantasyonu

- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Kubernetes ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secret Tipleri](https://kubernetes.io/docs/concepts/configuration/secret/#secret-types)
- [kubectl Komut Referansı](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands)

### En İyi Pratikler

- Hassas veriler için her zaman Secret kullanın (password'ler, token'lar, key'ler)
- Hassas olmayan yapılandırma için ConfigMap kullanın
- Secret'ları asla version control'e commit etmeyin
- Production için external secret management tool'ları düşünün (örn. HashiCorp Vault, AWS Secrets Manager)
- Secret'ları düzenli olarak rotate edin
- Secret'lara erişimi kontrol etmek için RBAC kullanın
