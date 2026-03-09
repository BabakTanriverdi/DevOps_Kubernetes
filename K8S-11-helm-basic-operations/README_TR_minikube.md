# 🚀 Hands-on Kubernetes-08: Helm Basics

> **Helm**, Kubernetes için bir **paket yöneticisidir** — tıpkı Ubuntu'daki `apt` veya macOS'taki `brew` gibi. Karmaşık Kubernetes uygulamalarını tek komutla kurar, günceller ve yönetir.

---

## 🎯 Learning Outcomes

Bu eğitimin sonunda öğrenciler şunları yapabilecek:

- Helm'in temel kavramlarını ve mimarisini açıklayabilecek
- Helm CLI ile chart kurma, güncelleme, geri alma işlemlerini yapabilecek
- Kendi Helm chart'ını sıfırdan oluşturabilecek
- GitHub'ı bir Helm chart repository olarak kullanabilecek

---

## 📋 Outline

- **Part 1** - Kubernetes Cluster Kurulumu (Minikube)
- **Part 2** - Helm ile Temel İşlemler
- **Part 3** - Helm Chart Oluşturma
- **Part 4** - GitHub'da Helm Chart Repository Kurulumu

---

## Part 1 - Kubernetes Cluster Kurulumu (Minikube)

### Cluster'ı Başlatma

Yerel Ubuntu makinende Minikube ile cluster başlatmak için:

```bash
# Docker sürücüsü ile başlat (önerilen)
minikube start --driver=docker

# Kaynak sınırı belirterek başlat (daha stabil çalışır)
minikube start --driver=docker --cpus=2 --memory=4096
```

> 💡 **Not:** Minikube, master ve worker rollerini **tek node'da** birleştirir. Helm öğrenmek için bu tamamen yeterlidir.
> 🔗 Minikube yerine tarayıcı üzerinden pratik yapmak için: https://killercoda.com/playgrounds

### Cluster Durumunu Kontrol Et

```bash
# Minikube'un çalışıp çalışmadığını kontrol et
minikube status

# Cluster bilgilerini göster
kubectl cluster-info

# Node'ların hazır olup olmadığını kontrol et
kubectl get nodes

# Daha detaylı node bilgisi
kubectl get nodes -o wide
```

> 💡 `kubectl`, Minikube başlatıldığında `~/.kube/config` dosyasını otomatik olarak yapılandırır. Aktif context'i doğrulamak için `kubectl config current-context` çalıştır — çıktı `minikube` olmalıdır.

---

## Part 2 - Helm ile Temel İşlemler

### 🔑 Helm'in Üç Temel Kavramı

| Kavram | Açıklama | Gerçek Dünya Karşılığı |
|--------|----------|------------------------|
| **Chart** | Bir uygulamayı Kubernetes'te çalıştırmak için gereken tüm kaynak tanımlarını içeren paket | `apt` paketi / `brew` formula |
| **Repository** | Chart'ların depolandığı ve paylaşıldığı yer | `apt` mirror / Docker Hub |
| **Release** | Bir chart'ın cluster içinde çalışan bir örneği. Aynı chart birden fazla kez kurulabilir, her biri ayrı bir release olur | Çalışan bir uygulama instance'ı |

> **Özet:** Helm, chart'ları Kubernetes'e kurar ve her kurulum için yeni bir release oluşturur.

---

### ⚙️ Helm Kurulumu

```bash
# Helm'i resmi script ile kur
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Kurulumu doğrula
helm version

# Beklenen çıktı örneği:
# version.BuildInfo{Version:"v3.x.x", ...}
```

> 📌 Helm 3, Helm 2'den farklı olarak **Tiller** bileşeni gerektirmez. Doğrudan `kubectl` kimlik bilgilerini kullanır — Minikube ile ek bir ayar yapmana gerek yoktur.

---

### 🔍 Chart Arama: `helm search`

Helm iki farklı kaynakta arama yapabilir:

```bash
# 1. Artifact Hub'da ara (artifacthub.io'a canlı istek atar)
helm search hub wordpress

# 2. Yerel cache'de ara (ağ bağlantısı gerekmez)
#    Kaynak: ~/.cache/helm/repository/
#    Bu cache, "helm repo update" ile doldurulur
helm search repo bitnami
```

---

### 📦 Repository Yönetimi

```bash
# Mevcut repo'ları listele
helm repo list

# Bitnami repo'sunu ekle
helm repo add bitnami https://charts.bitnami.com/bitnami
# helm repo remove bitnami

# Tüm repo'ları güncelle (en güncel chart listesini çek)
helm repo update

# Repo'daki tüm chart'ları listele
helm search repo bitnami

# Belirli bir chart'ı ara
helm search repo bitnami/postgresql
```

---

### 📥 Chart Kurulumu: `helm install`

```bash
# Önce repo'yu güncelle
helm repo update

# Mevcut release'leri listele
helm list

# PostgreSQL kur (release adı (kendimiz veriyoruz): my-release)
helm install my-release bitnami/postgresql

# Kurulumdan sonra release'leri tekrar listele
helm list
```

> 💡 **Release adı** (`my-release`) senin verdiğin isimdir. Aynı chart'ı farklı isimlerle birden fazla kez kurabilirsin.

> 🖥️ **Minikube'da Pod'ları İzle:** Kurulumun ardından pod'ların durumunu takip et:
> ```bash
> kubectl get pods --watch
> # Ctrl+C ile çıkabilirsin
> ```
> Eğer pod `Pending` durumunda kalıyorsa `kubectl describe pod <pod-adi>` ile sebebini öğren. Genellikle yetersiz bellek/CPU'dan kaynaklanır — `minikube stop && minikube start --memory=4096` ile daha fazla kaynak tanımlayabilirsin.

---

### 🔎 Chart Hakkında Bilgi Alma

```bash
# Chart'ın genel bilgilerini göster
helm show chart bitnami/postgresql

# Chart'ın tüm bilgilerini göster (values, README, vb.)
helm show all bitnami/postgresql

# Özelleştirilebilir değerleri göster
helm show values bitnami/postgresql

# Belirli bir değeri filtrele (örnek: password ayarları)
helm show values bitnami/postgresql | grep -i password
```

---

### ⚙️ Özelleştirilmiş Kurulum: `--set` ve `-f` Flags

```bash
# --set ile değerleri override ederek kur
helm install my-wordpress \
  --set wordpressUsername=admin \
  --set wordpressPassword=MySecurePass123 \
  --set mariadb.auth.rootPassword=RootPass456 \
  bitnami/wordpress

# Alternatif: values dosyası ile kur
# Önce values dosyası oluştur:
# helm show values bitnami/wordpress > my-values.yaml
# Sonra kur:
helm install my-wordpress -f my-values.yaml bitnami/wordpress
```

> 🖥️ **Minikube'da Servise Erişim:** WordPress web arayüzüne erişmek için (Minikube gerçek LoadBalancer IP'si vermez):
> ```bash
> minikube service my-wordpress --url
> # Çıktı: http://192.168.49.2:XXXXX  → bu adresi tarayıcıda aç
> ```

---

### 📋 Release Yönetimi

```bash
# Tüm release'leri listele
helm list
helm list --all-namespaces   # Tüm namespace'lerdeki release'ler

# Release detaylarını gör
helm status my-wordpress

# Release'in deploy ettiği tüm manifest'leri gör
helm get manifest my-wordpress

# Release'i kaldır
helm uninstall my-wordpress
helm uninstall my-release
```

---

## Part 3 - Helm Chart Oluşturma

### 📁 Chart Yapısı

```bash
# Yeni chart oluştur
helm create my-chart

# Oluşturulan dosya yapısını incele
ls my-chart/
```

Oluşturulan yapı:

```
my-chart/
├── Chart.yaml          # Chart metadata (isim, versiyon, açıklama)
├── values.yaml         # Varsayılan değerler
├── charts/             # Bağımlı chart'lar buraya gelir
└── templates/          # Kubernetes manifest template'leri
    ├── deployment.yaml
    ├── service.yaml
    ├── _helpers.tpl    # Yardımcı template fonksiyonları (adlandırma, label'lar)
    └── NOTES.txt       # Kurulum sonrası gösterilecek notlar
```

> 📌 `_helpers.tpl` dosyası alt çizgi `_` ile başladığı için Kubernetes'e **gönderilmez**. Sadece diğer template'ler tarafından kullanılan yardımcı fonksiyonlar içerir.

---

### 🧹 Template'leri Temizle ve Sıfırdan Başla

```bash
# Varsayılan template'leri sil
rm -rf my-chart/templates/*

# values.yaml'ı da temizle (isteğe bağlı)
echo "" > my-chart/values.yaml
```

---

### 📝 İlk Template: ConfigMap

`my-chart/templates/configmap.yaml` dosyasını oluştur:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-chart-config
data:
  myvalue: "my-chart configmap example"
  course: "DevOps"
```

```bash
# Chart'ı kur
helm install helm-demo my-chart

# Release'leri listele
helm list

# ConfigMap'i kontrol et
kubectl get configmap
kubectl describe configmap my-chart-config

# Release'i kaldır
helm uninstall helm-demo
```

---

### 🔧 Values Kullanımı (Dinamik Değerler)

`my-chart/values.yaml` dosyasını güncelle:

```yaml
course: DevOps
lesson:
  topic: helm
```

`my-chart/templates/configmap.yaml` dosyasını güncelle:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-config
data:
  myvalue: "my-chart configmap example"
  course: {{ quote .Values.course }}
  topic: {{ upper .Values.lesson.topic }}
  time: {{ now | date "2006.01.02" | quote }}
```

> 🔑 **Template Sözdizimi:**
> - `{{ .Values.xxx }}` → `values.yaml`'dan değer al
> - `{{ .Release.Name }}` → Helm release adı
> - `{{ .Chart.Name }}` → Chart adı
> - `{{ quote ... }}` → Değeri tırnak içine al
> - `{{ upper ... }}` → Büyük harfe çevir
> - `{{ now | date "2006.01.02" }}` → Tarih formatla (Go'nun referans tarihi)

> ⚠️ `2006.01.02` Go dilinin **sabit format kalıbıdır**: `2006=yıl`, `01=ay`, `02=gün`. Rastgele seçilmemiştir — Go'nun zaman paketinin başlangıç referans tarihidir.

---

### 🧪 Dry-Run ile Test Et

```bash
# --dry-run: Kubernetes'e hiçbir şey göndermez, sadece render eder
helm install --debug --dry-run mydryrun my-chart

# --set ile değer override ederek test et
helm install --debug --dry-run setflag my-chart --set course=AWS

# Sadece template'i render et (release oluşturmaz)
helm template my-chart
helm template my-release my-chart --set course=GCP
```

> 💡 `--dry-run` ile `helm template` arasındaki fark:
> - `--dry-run`: Kubernetes API'ye bağlanır, validation yapar
> - `helm template`: Tamamen offline çalışır, sadece YAML üretir

---

### 🏷️ Predefined (Yerleşik) Değerler

| Değer | Açıklama |
|-------|----------|
| `.Release.Name` | Release'in adı |
| `.Release.Namespace` | Release'in namespace'i |
| `.Release.IsInstall` | İlk kurulumsa `true` |
| `.Release.IsUpgrade` | Upgrade/rollback ise `true` |
| `.Release.Revision` | Revision numarası (1'den başlar) |
| `.Chart.Name` | Chart adı |
| `.Chart.Version` | Chart versiyonu |
| `.Chart.AppVersion` | Uygulama versiyonu |
| `.Values.xxx` | values.yaml'dan gelen değerler |

---

### 📣 NOTES.txt — Kurulum Sonrası Mesaj

`my-chart/templates/NOTES.txt` dosyasını oluştur:

```
🎉 {{ .Chart.Name }} başarıyla kuruldu!

Release adı  : {{ .Release.Name }}
Namespace    : {{ .Release.Namespace }}
Chart versyon: {{ .Chart.Version }}

Kurulum hakkında bilgi almak için:
  $ helm status {{ .Release.Name }}
  $ helm get all {{ .Release.Name }}

Tüm manifest'leri görmek için:
  $ helm get manifest {{ .Release.Name }}

Minikube üzerinde servise erişmek için:
  $ minikube service {{ .Release.Name }} --url
```

```bash
# Chart'ı kur — NOTES.txt otomatik gösterilir
helm install notes-demo my-chart
```

---

### 🔄 Upgrade ve Rollback

```bash
# Chart'ı upgrade et
helm upgrade notes-demo my-chart

# Tüm revision geçmişini gör
helm history notes-demo

# Belirli bir revision'a geri dön (örnek: revision 1)
helm rollback notes-demo 1

# Rollback sonrası durumu kontrol et
helm history notes-demo
kubectl describe configmap notes-demo-config

# Release'i kaldır
helm uninstall notes-demo
helm list
kubectl get configmap
```

> 📌 `helm history` çıktısı örneği:
> ```
> REVISION  STATUS      DESCRIPTION
> 1         superseded  Install complete
> 2         superseded  Upgrade complete
> 3         deployed    Rollback to 1
> ```

---

## Part 4 - GitHub'da Helm Chart Repository Kurulumu

### 🌐 Neden Chart Repository?

Bir chart repository, paketlenmiş chart'ların depolandığı ve paylaşıldığı bir **HTTP sunucusudur**. `index.yaml` dosyası ve `.tgz` chart paketleri barındırır.

---

### 🔑 GitHub Personal Access Token Oluştur

1. GitHub → **Avatar** → **Settings** → **Developer settings**
2. **Personal access tokens** → **Tokens (classic)** → **Generate new token**
3. `repo` scope'unu seç
4. Token'ı kopyala ve güvenli bir yere kaydet (bir daha göremezsin!)

> 💡 Token'ı terminal oturumunda ortam değişkeni olarak saklayabilirsin:
> ```bash
> export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
> # Sonra --password $GITHUB_TOKEN şeklinde kullanabilirsin
> ```

---

### 📁 GitHub Repo Oluştur ve Yerel Kur

```bash
mkdir mygithubrepo
cd mygithubrepo

echo "# mygithubrepo" >> README.md
git init
git add README.md

git config --global user.email "you@example.com"
git config --global user.name "Your Name"

git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/<github-kullanici-adin>/mygithubrepo.git
git push -u origin main
```

---

### 📦 Chart'ı Paketle ve Index Oluştur

```bash
cd mygithubrepo

# my-chart'ı paketle (.tgz dosyası oluşturur)
helm package ../my-chart

# index.yaml oluştur
helm repo index .

# GitHub'a push et
git add .
git commit -m "my-chart added to helm repo"
git push
```

---

### 🔗 Repo'yu Helm'e Ekle

```bash
helm repo list

helm repo add \
  --username <github-kullanici-adin> \
  --password <personal-access-token> \
  my-github-repo \
  'https://raw.githubusercontent.com/<github-kullanici-adin>/mygithubrepo/main'

helm repo list
helm search repo my-github-repo
```

---

### ➕ Yeni Chart Ekle

```bash
cd ..
helm create second-chart
cd mygithubrepo

helm package ../second-chart
helm repo index .

git add .
git commit -m "second-chart added"
git push

helm repo update
helm search repo my-github-repo
```

---

### 🚀 GitHub Repo'sundan Release Kur

```bash
helm install github-repo-release my-github-repo/second-chart

helm list
kubectl get deployment
kubectl get service
kubectl get pods
```

---

### 🧹 Temizlik

```bash
helm uninstall github-repo-release
helm repo remove my-github-repo
helm repo list
```

---

## 📚 Özet: Sık Kullanılan Helm Komutları

```bash
# Repo yönetimi
helm repo add <name> <url>          # Repo ekle
helm repo update                    # Repo'ları güncelle
helm repo list                      # Repo'ları listele
helm repo remove <name>             # Repo kaldır

# Chart arama
helm search hub <keyword>           # Artifact Hub'da ara
helm search repo <keyword>          # Yerel repo'larda ara

# Chart bilgisi
helm show chart <chart>             # Chart metadata
helm show values <chart>            # Varsayılan değerler
helm show all <chart>               # Tüm bilgiler

# Kurulum ve yönetim
helm install <release> <chart>                 # Kur
helm install <release> <chart> --set key=val   # Değer override ile kur
helm install <release> <chart> -f values.yaml  # Dosya ile kur
helm upgrade <release> <chart>                 # Güncelle
helm rollback <release> <revision>             # Geri al
helm uninstall <release>                       # Kaldır

# Durum ve debug
helm list                           # Release'leri listele
helm list --all-namespaces          # Tüm namespace'lerdeki release'ler
helm status <release>               # Release durumu
helm history <release>              # Revision geçmişi
helm get manifest <release>         # Deploy edilen manifest'ler
helm get values <release>           # Kullanılan değerler
helm template <chart>               # Offline render (kurulum yapmaz)
helm install --dry-run --debug ...  # Test kurulumu

# Chart oluşturma
helm create <chart-name>            # Yeni chart iskeleti oluştur
helm package <chart-dir>            # Chart'ı paketle (.tgz)
helm repo index <dir>               # index.yaml oluştur/güncelle
helm lint <chart-dir>               # Chart'ı syntax açısından kontrol et
```

---

## 🔗 Faydalı Kaynaklar

- [Helm Resmi Dokümantasyon](https://helm.sh/docs/)
- [Helm GitHub Releases](https://github.com/helm/helm/releases)
- [Artifact Hub — Chart Arama](https://artifacthub.io/)
- [Sprig Template Fonksiyonları](https://masterminds.github.io/sprig/)
- [Go Template Dili](https://pkg.go.dev/text/template)
- [SemVer 2.0 Versiyonlama](https://semver.org/)
- [Minikube Resmi Dokümantasyon](https://minikube.sigs.k8s.io/docs/)
- [Killercoda Kubernetes Playground](https://killercoda.com/playgrounds)
