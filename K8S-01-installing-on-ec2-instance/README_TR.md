# Uygulamalı Kubernetes-01: AWS EC2 Instance'larında Çalışan Ubuntu Üzerine Kubernetes Kurulumu

Bu uygulamalı eğitimin amacı, öğrencilere Ubuntu EC2 Instance'ları üzerinde Kubernetes'i nasıl kurup yapılandıracaklarını öğretmektir.

## Öğrenim Çıktıları

Bu uygulamalı eğitimin sonunda öğrenciler;

- Ubuntu üzerinde Kubernetes kurabilecek.

- Kubernetes kurulum adımlarını açıklayabilecek.

- Bir Kubernetes cluster'ı kurup yapılandırabilecek.

- Kubernetes mimarisini açıklayabilecek.

- Kubernetes cluster'ı üzerinde basit bir server deploy edebilecek.

## İçindekiler

- Bölüm 1 - Tüm Node'larda Kubernetes Ortamını Kurma

- Bölüm 2 - Master Node'u Kubernetes İçin Ayarlama

- Bölüm 3 - Slave/Worker Node'ları Cluster'a Ekleme

- Bölüm 4 - Kubernetes Üzerinde Basit Bir Nginx Server Deploy Etme

- Bölüm 5 - Kubernetes Üzerinde Basit Bir Nginx Server Deploy Etme

## Bölüm 1 - Tüm Node'larda Kubernetes Ortamını Kurma

- Bu uygulamada, `Ubuntu 24.04` üzerinde Kubernetes için iki node hazırlayacağız. Node'lardan biri Master node olarak, diğeri ise worker node olarak yapılandırılacaktır. Aşağıdaki adımlar tüm node'larda çalıştırılmalıdır. _Not: Kubernetes'in verimli çalışması için minimum `2 CPU Core` ve `2GB RAM` olan makinelere kurulması önerilir. Bu nedenle, `2 CPU Core` ve `4 GB RAM`'e sahip olan `t2.medium` EC2 instance tipini seçeceğiz._

- Kubernetes için [gerekli portları](https://kubernetes.io/docs/reference/networking/ports-and-protocols/) kısaca açıklayın.

- İki security group oluşturun. İlk security group'u master-sec-group olarak adlandırın ve aşağıdaki Control-plane (Master) Node(s) tablosunu master node'unuza uygulayın.

- İkinci security group'u worker-sec-group olarak adlandırın ve aşağıdaki Worker Node(s) tablosunu worker node'larınıza uygulayın.

### Control-plane (Master) Node(s)

|Protocol|Direction|Port Range|Amaç|Kullanan|
|---|---|---|---|---|
|TCP|Inbound|6443|Kubernetes API server|Tümü|
|TCP|Inbound|2379-2380|`etcd` server client API|kube-apiserver, etcd|
|TCP|Inbound|10250|Kubelet API|Self, Control plane| \*\*
|TCP|Inbound|10259|kube-scheduler|Self|
|TCP|Inbound|10257|kube-controller-manager|Self|
|TCP|Inbound|22|ssh ile uzaktan erişim|Self|
|UDP|Inbound|8472|Cluster Genelinde Network İletişimi - Flannel VXLAN|Self|

### Worker Node(s)

|Protocol|Direction|Port Range|Amaç|Kullanan|
|---|---|---|---|---|
|TCP|Inbound|10250|Kubelet API|Self, Control plane|
|TCP|Inbound|10256|kube-proxy|Self, Load balancers| \*\*
|TCP|Inbound|30000-32767|NodePort Services|Tümü|
|TCP|Inbound|22|ssh ile uzaktan erişim|Self|
|UDP|Inbound|8472|Cluster Genelinde Network İletişimi - Flannel VXLAN|Self|

> **AWS instance'ları için bu bölümü göz ardı edin. Ancak gerçek server'lar/workstation'lar için uygulanmalıdır.**
>
> - `/etc/fstab` dosyasında swap'i ifade eden satırı bulun ve aşağıdaki gibi yorum satırı haline getirin.

```bash
 # Swap a usb extern (3.7 GB):
 #/dev/sdb1 none swap sw 0 0
```

> veya,
>
> - Komut satırından swap'i devre dışı bırakın

```bash
free -m
sudo swapoff -a && sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

- Node'ların hostname değişikliği yapılmalıdır, böylece her node'un rolünü ayırt edebiliriz. Örneğin, node'ları (instance'ları) `kube-master, kube-worker1` gibi isimlendirebilirsiniz

```bash
sudo hostnamectl set-hostname worker
bash
```

### Container Runtime'larını Kurma

- [Kubernetes Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/) dokümantasyonuna göre gerekli container runtime'ları kuruyoruz.

#### Ön koşulları kurma ve yapılandırma

- IPv4 yönlendirmesi ve iptables'ın bridge edilen trafiği görmesini sağlama:

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup tarafından gereken sysctl parametreleri, yeniden başlatmalarda kalıcıdır
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Yeniden başlatma olmadan sysctl parametrelerini uygula
sudo sysctl --system
```

- br_netfilter ve overlay modüllerinin yüklendiğini aşağıdaki komutları çalıştırarak doğrulayın:

```bash
lsmod | grep br_netfilter
lsmod | grep overlay
```

- net.bridge.bridge-nf-call-iptables, net.bridge.bridge-nf-call-ip6tables ve net.ipv4.ip_forward sistem değişkenlerinin sysctl config dosyanızda 1 olarak ayarlandığını aşağıdaki komutu çalıştırarak doğrulayın:

```bash
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
```

#### Ubuntu üzerine containerd kurulumu (https://docs.docker.com/engine/install/ubuntu/)

- Docker'ın apt repository'sini kurun.

```bash
# Docker'ın resmi GPG key'ini ekle:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Repository'yi Apt sources'a ekle:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
```

- containerd'i kurun.

```bash
sudo apt-get install containerd.io
```

- containerd'i kontrol edin.

```bash
sudo systemctl status containerd
```

- containerd'i test edin.

```bash
sudo ctr images pull docker.io/library/redis:alpine
sudo ctr run -d docker.io/library/redis:alpine redis
sudo ctr container ls
```

#### nerdctl'yi Kurma (Opsiyonel)

- ctr aracı containerd ile birlikte gelse de, ctr aracının yalnızca containerd'i debug etmek için yapıldığını unutmamak gerekir. nerdctl aracı daha stabil ve kullanıcı dostu bir deneyim sağlar.

- nerdctl binary dosyasını nerdctl GitHub sayfasından indirin. (https://github.com/containerd/nerdctl/releases)

- `nerdctl-full-*-linux-amd64.tar.gz` release'ini indirin.

```bash
wget https://github.com/containerd/nerdctl/releases/download/v2.0.3/nerdctl-full-2.0.3-linux-amd64.tar.gz
```

- Archive dosyasını `/usr/local` gibi bir yola çıkartın.

```bash
sudo tar xvf nerdctl-full-2.0.3-linux-amd64.tar.gz -C /usr/local
```

- `nerdctl`'yi test edin.

```bash
sudo nerdctl run -d --name redis redis:alpine
sudo nerdctl container ls
```

#### cgroup driver'ları (https://kubernetes.io/docs/setup/production-environment/container-runtimes/)

- Linux'ta, control group'lar process'lere tahsis edilen kaynakları kısıtlamak için kullanılır.

- Hem kubelet hem de alttaki container runtime'ın, pod'lar ve container'lar için kaynak yönetimini zorlamak ve CPU/bellek istekleri ve limitleri gibi kaynakları ayarlamak için control group'larla arayüz oluşturması gerekir. Control group'larla arayüz oluşturmak için kubelet ve container runtime'ın bir cgroup driver kullanması gerekir. `Kubelet ve container runtime'ın aynı cgroup driver'ı kullanması ve aynı şekilde yapılandırılması kritik önem taşır`.

- İki cgroup driver mevcut:

  cgroupfs
  systemd

#### containerd için systemd cgroup driver'ını Yapılandırma.

- containerd'i systemd'yi cgroup olarak kullanacak şekilde yapılandırın.

```bash
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
```

containerd servisini yeniden başlatın ve etkinleştirin

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

### kubeadm'i Kurma (https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)

- Kubernetes için yardımcı paketleri kurun.

```bash
# apt paket index'ini güncelleyin ve Kubernetes apt repository'sini kullanmak için gereken paketleri kurun:

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Google Cloud public signing key'ini indirin:

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Kubernetes apt repository'sini ekleyin:

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

- Kubernetes paketlerini kurun.

```bash
sudo apt-get update

sudo apt-get install -y kubectl kubeadm kubelet kubernetes-cni

sudo apt-mark hold kubelet kubeadm kubectl
```

## Bölüm 2 - Master Node'u Kubernetes İçin Ayarlama (https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)

- Aşağıdaki komutlar yalnızca Master Node üzerinde çalıştırılmalıdır.

- Kubernetes paketlerini önceden çekin

```bash
sudo kubeadm config images pull
```

- `kubeadm`'in sizin için ortamı hazırlamasına izin verin. Not: `<ec2-private-ip>` yerine master node'unuzun private IP'sini yazmayı unutmayın.

```bash
sudo kubeadm init --apiserver-advertise-address=172.31.80.28 --pod-network-cidr=10.244.0.0/16
```

> :warning: **Not**: `t2.micro` veya `t2.small` instance'ları üzerinde çalışıyorsanız, hataları yok saymak için aşağıda gösterildiği gibi `--ignore-preflight-errors=NumCPU` ile komutu kullanın.

```bash
sudo kubeadm init --apiserver-advertise-address=172.31.88.58 --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=NumCPU
```

> **Not**: Birçok pod network provider vardır ve bazıları önceden tanımlanmış bir `--pod-network-cidr` bloğu kullanır. Referanslar bölümündeki dokümantasyonu kontrol edin. Biz pod network için Flannel kullanacağız ve Flannel 10.244.0.0/16 CIDR bloğunu kullanır.

> - Sorun olması durumunda, initialization'ı sıfırlamak ve Bölüm 2'den (Master Node'u Kubernetes İçin Ayarlama) yeniden başlamak için aşağıdaki komutu kullanın.

```bash
sudo kubeadm reset
```

- Başarılı initialization'dan sonra, aşağıdaki çıktıya benzer bir şey görmelisiniz (kısaltılmış versiyon).

```bash
...
Kubernetes control-plane'iniz başarıyla initialize edildi!

Cluster'ınızı kullanmaya başlamak için, aşağıdakileri normal bir kullanıcı olarak çalıştırmanız gerekir:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatif olarak, root kullanıcısıysanız, şunu çalıştırabilirsiniz:

  export KUBECONFIG=/etc/kubernetes/admin.conf

Şimdi cluster'a bir pod network deploy etmelisiniz.
Aşağıdaki seçeneklerden biriyle "kubectl apply -f [podnetwork].yaml" komutunu çalıştırın:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Ardından, her birinde root olarak aşağıdakileri çalıştırarak herhangi bir sayıda worker node'u ekleyebilirsiniz:

kubeadm join 172.31.32.92:6443 --token 6grb8s.6jjyof8xi8vtxztb \
        --discovery-token-ca-cert-hash sha256:32d1c906fddc50a865b533f909377b2219ef650373ca1b7d4310de025817a00b
```

> Worker node'larınızı master node'a bağlamak için `kubeadm join ...` kısmını not edin. Bu komutu `sudo` ile çalıştırmayı unutmayın.

- Master node üzerinde local `kubeconfig` kurmak için aşağıdaki komutları çalıştırın.

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

- `Flannel` pod networking'i etkinleştirin ve `https://kubernetes.io/docs/concepts/cluster-administration/addons/` adresindeki network add-on'ları hakkında kısaca bilgi verin.

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

- Master node (Control Plane olarak da adlandırılır) hazır olmalıdır ve kullanıcı tarafından oluşturulan mevcut pod'ları göstermelidir. Henüz herhangi bir pod oluşturmadığımız için liste boş olmalıdır.

```bash
kubectl get nodes
```

- Kubernetes servisinin kendisi için oluşturulan pod'ların listesini gösterin. Kubernetes servisinin pod'larının master node üzerinde çalıştığını unutmayın.

```bash
kubectl get pods -n kube-system
```

- `kube-system` namespace'indeki pod'ların detaylarını gösterin. Kubernetes servisinin pod'larının master node üzerinde çalıştığını unutmayın.

```bash
kubectl get pods -n kube-system -o wide
```

- Container'ları `nerdctl` komutuyla da görebiliriz.

```bash
sudo nerdctl --namespace k8s.io ps -a
```

- Mevcut servisleri alın. Henüz herhangi bir servis oluşturmadığımız için sadece Kubernetes servisini görmeliyiz.

```bash
kubectl get services
```

## Bölüm 3 - Worker Node'ları Cluster'a Ekleme

- Node'ların listesini gösterin. Cluster'a henüz worker node'ları eklemediğimiz için, listede yalnızca master node'un kendisini görmeliyiz.

```bash
kubectl get nodes
```

- `Master node` üzerinde kubeadm `join command` komutunu alın.

```bash
kubeadm token create --print-join-command
```

- `Worker node` üzerinde cluster'a katılmaları için `sudo kubeadm join...` komutunu çalıştırın.

```bash
sudo kubeadm join 172.31.80.28:6443 --token cltpxd.r22xpq4rre32p3co --discovery-token-ca-cert-hash sha256:9c64d11df9746a09d6ddc45d1eedf59905df57d232fd4ef43dc7d24979d480ce
```

- Master node'a gidin. Node'ların listesini alın. Şimdi listede yeni worker node'ları görmeliyiz.

```bash
kubectl get nodes
```

- Node'ların detaylarını alın.

```bash
kubectl get nodes -o wide
```

## Bölüm 4 - Kubernetes Üzerinde Basit Bir Nginx Server Deploy Etme

- Master node üzerinde cluster'daki node'ların hazır olup olmadığını kontrol edin.

```bash
kubectl get nodes
```

- Master üzerinde default namespace'deki mevcut pod'ların listesini gösterin. Henüz herhangi bir pod oluşturmadığımız için liste boş olmalıdır.

```bash
kubectl get pods
```

- Master üzerinde tüm namespace'lerdeki pod'ların detaylarını alın. Kubernetes servisinin pod'larının master node üzerinde çalıştığını ve ayrıca worker node'larda Kubernetes servisi için iletişim ve yönetim sağlamak üzere ek pod'ların çalıştığını unutmayın.

```bash
kubectl get pods -o wide --all-namespaces
```

- Basit bir `Nginx` Server image'ı oluşturun ve çalıştırın.

```bash
kubectl run nginx-server --image=nginx  --port=80
```

- Master üzerinde default namespace'deki pod'ların listesini alın ve `nginx-server`'ın durumunu ve hazır olup olmadığını kontrol edin

```bash
kubectl get pods -o wide
```

- nginx-server pod'unu master üzerinde yeni bir Kubernetes servisi olarak expose edin.

```bash
kubectl expose pod nginx-server --port=80 --type=NodePort
```

- Servislerin listesini alın ve yeni oluşturulan `nginx-server` servisini gösterin

```bash
kubectl get service -o wide
```

- Şuna benzer bir çıktı alacaksınız.

```bash
kubernetes     ClusterIP   10.96.0.1       <none>        443/TCP        13m    <none>
nginx-server   NodePort    10.110.144.60   <none>        80:32276/TCP   113s   run=nginx-server
```

- Nginx Server'ın çalışıp çalışmadığını görmek için bir tarayıcı açın ve worker node'un `public ip:<NodePort>` adresini kontrol edin. Bu örnekte NodePort 32276'dır.

- Cluster'dan servisi ve pod'u temizleyin.

```bash
kubectl delete service nginx-server
kubectl delete pods nginx-server
```

- Default namespace'de pod kalmadığını kontrol edin.

```bash
kubectl get pods
```

### Cluster'dan bir worker node'u silme

- Cluster'dan bir worker node'u silmek için aşağıdaki adımları izleyin.
  - Master üzerinde worker node'u drain edin ve silin.

```bash
  kubectl get nodes
  kubectl cordon kube-worker1
  kubectl drain kube-worker1 --ignore-daemonsets --delete-emptydir-data

  kubectl delete node kube-worker1
```

- Worker node üzerindeki ayarları kaldırın ve sıfırlayın.

```bash
  sudo kubeadm reset
```

> Not: Worker'ın cluster'a yeniden katılmasını sağlamaya çalışırsanız, yeniden katılmadan önce `kubelet.conf` ve `ca.crt` dosyalarını temizlemek ve `10250` portunu boşaltmak gerekebilir.

```bash
  sudo rm /etc/kubernetes/kubelet.conf
  sudo rm /etc/kubernetes/pki/ca.crt
  sudo netstat -lnp | grep 10250
  sudo kill <process-id>
```

# Referanslar

- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

- https://kubernetes.io/docs/concepts/cluster-administration/addons/

- https://kubernetes.io/docs/reference/

- https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#-strong-getting-started-strong-
