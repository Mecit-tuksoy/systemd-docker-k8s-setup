#!/bin/bash

# Hata ayıklama modu (isteğe bağlı)
set -e

# Kubectl indiriliyor
echo "Kubectl v1.31.0 indiriliyor..."
curl -LO "https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl"

# SHA256 doğrulama dosyasını indir
echo "Kubectl binary doğrulama işlemi yapılıyor..."
curl -LO "https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl.sha256"

# SHA256 doğrulaması yap
echo "SHA256 doğrulaması yapılıyor..."
echo "$(cat kubectl.sha256) kubectl" | sha256sum --check

# Kubectl dosyasını çalıştırılabilir hale getir
chmod +x kubectl

# Sistemdeki bir PATH konumuna taşı
sudo mv kubectl /usr/local/bin/

# Kubectl sürüm kontrolü
echo "Kubectl kuruldu. Sürüm bilgisi:"
kubectl version --client --output=yaml

# Temizlik: Geçici dosyaları sil
rm -f kubectl.sha256