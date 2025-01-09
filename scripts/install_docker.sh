#!/bin/bash

# Eski Docker kurulumlarını kaldır
echo "Mevcut Docker kurulumları kaldırılıyor..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc

# Sistemi güncelle ve bağımlılıkları yükle
echo "Gerekli bağımlılıklar yükleniyor..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Docker resmi GPG anahtarını ekle
echo "Docker GPG anahtarı ekleniyor..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /usr/share/keyrings/docker-archive-keyring.gpg > /dev/null

# Docker repository'sini ekle
echo "Docker repository'si ekleniyor..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker yükleniyor
echo "Docker yükleniyor..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Docker kurulumunu doğrula
echo "Docker sürümü:"
docker --version

# Docker daemon'un otomatik başlatılmasını sağla ve başlat
sudo systemctl enable docker
sudo systemctl start docker

# Docker grubuna kullanıcıyı ekle
echo "Kullanıcı Docker grubuna ekleniyor..."
sudo usermod -aG docker $USER

# Jenkins kullanıcısını Docker grubuna ekle
if id "jenkins" &>/dev/null; then
    echo "Jenkins kullanıcısı Docker grubuna ekleniyor..."
    sudo usermod -aG docker jenkins
else
    echo "Jenkins kullanıcısı bulunamadı, atlanıyor..."
fi

newgrp docker


# Docker Compose yükleme

echo "Docker Compose yükleniyor..."

sudo curl -L "https://github.com/docker/compose/releases/download/v2.31.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose



# Docker Compose sürümünü kontrol etme

echo "Docker Compose sürümü:"

docker-compose version