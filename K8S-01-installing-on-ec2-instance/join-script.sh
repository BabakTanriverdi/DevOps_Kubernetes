#!/bin/bash
#Get join Token
kubeadm token list | awk 'NR == 2 {print $1}'

# Get Discovery Token CA cert Hash
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'

# Get API Server Advertise address
kubectl cluster-info | awk 'NR == 1 {print $7}'

# Join a new Kubernetes Worker Node a Cluster

# sudo kubeadm join \
#   <control-plane-host>:<control-plane-port> \
#   --token <token> \
#   --discovery-token-ca-cert-hash sha256:<hash>

# sudo kubeadm join \
#   192.168.122.195:6443 \
#   --token nx1jjq.u42y27ip3bhmj8vj \
#   --discovery-token-ca-cert-hash sha256:c6de85f6c862c0d58cc3d10fd199064ff25c4021b6e88475822d6163a25b4a6c

# Compact version... 
sudo kubeadm join \
  ${KubeMaster1.PrivateIp}:6443 \
  --token $(kubeadm token list | awk 'NR == 2 {print $1}') \
  --discovery-token-ca-cert-hash sha256:$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')

# With EC2 Instance Connect CLI and mssh

kubeadm join ${KubeMaster1.PrivateIp}:6443 --token $(mssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r ${AWS::Region} ubuntu@${KubeMaster1} kubeadm token list | awk 'NR == 2 {print $1}') --discovery-token-ca-cert-hash sha256:$(mssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r ${AWS::Region} ubuntu@${KubeMaster1} openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')




# #!/bin/bash
# set -e  # Stop on error

# # Run on master node
# MASTER_IP="192.168.122.195"
# MASTER_PORT="6443"

# # Create new token (valid for 24 hours)
# TOKEN=$(sudo kubeadm token create)

# # Get CA cert hash
# CA_HASH=$(sudo openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
#   | openssl rsa -pubin -outform der 2>/dev/null \
#   | openssl dgst -sha256 -hex \
#   | sed 's/^.* //')

# # Print join command to run on worker node
# echo "Run this command on worker node:"
# echo ""
# echo "sudo kubeadm join ${MASTER_IP}:${MASTER_PORT} \\"
# echo "  --token ${TOKEN} \\"
# echo "  --discovery-token-ca-cert-hash sha256:${CA_HASH}"

# # Or generate join command directly
# sudo kubeadm token create --print-join-command