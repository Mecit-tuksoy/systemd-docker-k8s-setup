# Task 1

````sh
python3 --version           #python3 yüklümü? Yüklü değilse yüklemek için:
sudo apt update && sudo apt install python3
which python3               #python3'ün yolunu öğreniyoruz.
pwd                         #uygulammnın olduğu konumu service dosyasında kullanacağımız için alıyoruz.
````
````sh
pip3 list | grep flask            # gerekli olan flask freamework yüklümü kontrol ediyoruz.
pip3 install -r requirements.txt  # requirements.txt dosyasında bulunan gerekli paketler yüklenecek.
````


````sh
sudo nano /etc/systemd/system/myapp.service  # service dosyası oluşturuyoruz.
````
````sh
[Unit]
Description=MyApp Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/task1/app.py
WorkingDirectory=/mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/task1
Restart=always
StandardOutput=file:/var/log/myapp.log
StandardError=file:/var/log/myapp-error.log
User=mecit

[Install]
WantedBy=multi-user.target
````

```sh
sudo ls -l /var/log | grep myapp.log
sudo ls -l /var/log | grep myapp-error.log
sudo chown mecit:mecit /var/log/myapp.log /var/log/myapp-error.log

# Eğer dosyalar yok ise veya izinleri yeterli değilse aşağıdaki gibi dosyaları ekleyip izinleri ayarlayabilirsiniz. 
sudo touch /var/log/myapp.log /var/log/myapp-error.log
sudo chmod 666 /var/log/myapp.log /var/log/myapp-error.log
```
Uygulamamız 8080 portunda çalışacağı için sisteminizdeki portları kontrol edioruz. 
```sh
sudo lsof -i :8080  #8080 portunu kullanan uygulamayı verir
#Benim sistemimde jenkins çalışıyordu onuda aşağıdaki komutla şimdilik durdurdum.
sudo systemctl stop jenkins
```

Son olarak yaptığınız değişikliklerden sonra systemd daemon'ını yeniden yükleyip servisi başlatıyoruz.
````sh
sudo systemctl daemon-reload
sudo systemctl restart myapp.service`
#loglar tutulmuş mu bakmak için:
cat /var/log/myapp-error.log
````

# Task 2

app.py uygulama dosyamızı ve requirements.txt dosyasını *task2* dosyasına kopyalıyoruz.

````sh
cd ..
mkdir docker
cd docker
cp /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/systemd/app.py .
cp /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/systemd/requirements.txt .
````

*Dockerfile* dosyası oluşturuyoruz.

````sh
FROM python:3.9-slim
WORKDIR /app
COPY . /app
RUN pip install -r requirements.txt
EXPOSE 8080
CMD ["python", "app.py"]

````

Uygulamayı çalıştıracak *docker-compose.yml* dosyasını oluşturuyoruz.

```sh
version: '3.8'
services:
  app:
    build: .
    deploy:
      replicas: 2
      restart_policy:
        condition: on-failure
    networks:
      - app_network

  nginx:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - app
    networks:
      - app_network

networks:
  app_network:
    driver: bridge
```


Nginx image'ı içine taşımak üzere bir *nginx.conf* dosyası oluşturuyoruz. (compose dosyasında belirttik.)

````sh
events {
    worker_connections 1024; # Maksimum eş zamanlı bağlantı sayısı
}

http {
    upstream app_servers {
        server app:8080; # Flask uygulaması konteynerini hedef alın
    }

    server {
        listen 80;

        location / {
            proxy_pass http://app_servers;
        }
    }
}

````

Uygulamayı çalıştırmak için:

````sh
docker-compose up
#yukarıdaki ayarlamalara göre uygulamamızı tarayıcıya "http://localhost/" yazdığımızda görebiliyor olmamız gerekiyor.
#uygulama sağlıklı bir şekilde çalışıyor ise sonlandırma işlemi için:
docker-compose down   
````

# Task 3

## app.py uygulama dosyamızı, requirements.txt ve Dockerfile dosyasını *k8s* dosyasına kopyalıyoruz.

````sh
cd ..
mkdir k8s
cd k8s
cp /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/docker/app.py .
cp /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/docker/requirements.txt .
cp /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/docker/Dockerfile .
````

## image oluşturup Dockerhub'a push ediyoruz:

````sh
docker build -t mecit35/flask-app .
docker login
docker push mecit35/flask-app:latest
````



Kubernetes'e uygulama dağıtımı için gerekli olan *Deployment*, *Service*, ve *Ingress* gibi manifest dosyalarını aşağıdaki gibi oluşturuyoruz.

deployment.yaml:
````sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: mecit35/flask-app:latest
        ports:
        - containerPort: 8080

````


service.yaml:

````sh
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
spec:
  selector:
    app: my-app
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
````


ingress.yaml:

````sh
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
spec:
  rules:
  - host: localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-service
            port:
              number: 80

````
