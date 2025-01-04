# Task 1

The purpose of this task is to run a Python Flask application that prints "Hello everyone!" as a systemd service on Ubuntu. The service should remain active, ensure logs are recorded correctly, and automatically restart in case of potential errors.

````sh
python3 --version           #Check if python3 is installed. If not, install it using the following command:
sudo apt update && sudo apt install python3
which python3               #Find the path of python3 to use it in the service file.
pwd                         #Get the current directory path where the application is located, to use it in the service file.
````
````sh
pip3 list | grep flask            #  Check if the required Flask framework is installed.
pip3 install -r requirements.txt  # Install necessary packages from the requirements.txt file.
````


````sh
sudo nano /etc/systemd/system/myapp.service  #Create the service file.
````
````sh
[Unit]
Description=MyApp Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/systemd/app.py
WorkingDirectory=/mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/systemd
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

# If the files do not exist or if the permissions are not sufficient, you can create the files and set the correct permissions as follows:
sudo touch /var/log/myapp.log /var/log/myapp-error.log
sudo chmod 666 /var/log/myapp.log /var/log/myapp-error.log
```

Finally, reload the systemd daemon and start the service:
````sh
sudo systemctl daemon-reload
sudo systemctl start myapp.service
sudo systemctl enable myapp.service
# Check if logs are being recorded:
cat /var/log/myapp-error.log
sudo systemctl status myapp.service  # Check the service status:
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


Nginx image'ın içine taşımak üzere bir *nginx.conf* dosyası oluşturuyoruz. (compose dosyasında belirttik.)

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

## app.py uygulama dosyamızı, requirements.txt ve Dockerfile dosyasını *k8s* klasörü altında *my-app-version1* ve *my-app-version2* klasörlerine kopyalıyoruz.

````sh
cd ..
cd k8s/my-app-version1
cp /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/docker/app.py .
cp /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/docker/requirements.txt .
cp /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/docker/Dockerfile .
cd k8s/my-app-version2
cp /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/docker/app.py .
cp /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/docker/requirements.txt .
cp /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/docker/Dockerfile .
````

my-app-version1 klasöründeki app.py uygulamasında bulunan "Hello everyone!" yazan yeri "Hello from version 1!" ve
my-app-version2 klasöründeki app.py uygulamasında bulunan "Hello everyone!" yazan yeri "Hello from version 2!" olarak değiştiriyoruz.

## image oluşturup Dockerhub'a push ediyoruz:

my-app-version1 klasöründe aşağıdaki ilk komutları çalıştırarak uygulamanın *v1* versionunu, 
my-app-version2 klasöründe aşağıdaki ikinci komutları çalıştırarak uygulamanın *v2* versionunu dockerhub'a push ediyoruz.

````sh
docker build -t mecit35/flask-app:v1 .
docker login
docker push mecit35/flask-app:v1
````
````sh
docker build -t mecit35/flask-app:v2 .
docker login
docker push mecit35/flask-app:v2
````

## Kubernetes dosyalarının oluşturulması:

Kubernetes'e uygulama dağıtımı için gerekli olan *HorizontalPodAutoscaler*, *Deployment*, *Service*, ve *Ingress* gibi manifest dosyalarını aşağıdaki gibi oluşturuyoruz.

hpa.yaml:
````sh
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
````

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
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
        ports:
        - containerPort: 8080
      
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "100m"
            memory: "128Mi"

````

service.yaml:

````sh
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
  - port: 80     
    targetPort: 8080 
````


ingress.yaml:

````sh
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: default
spec:
  rules:
  - host: mecit.com
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

## Helm Chart oluşturulması:

Bir Chart oluşturmak için:

````sh
helm create my-app-chart
rm -rf my-app-chart/templates/*   #templates klasörü içinde gelen manifest dosyalarını siliyoruz.
````

Yukarda oluşturduğumuz kubernetes dosyalarını *my-app-chart/templates/* konumuna taşıyoruz. 

chart'ın içinde gelen *values.yaml* dosyasının içini silip aşağıdaki değişkeni ekliyoruz:

````sh
image:
  repository: mecit35/flask-app
  tag: v1
````

Chart'ın içinde bulunan *Chart.yaml* dosyasındaki *"version"* yazan yere ilk çartımız için *"version: 1.0.0"* ve
Chart'ın içinde bulunan *Chart.yaml* dosyasındaki *"appVersion"* yazan yere ilk çartımız için *"appVersion: "1.0.0""* yazıyoruz.

Bu değişikliklerden sonra çartımız hazır. şimdi bu Chartı Github repomuza puşlamamız gerekiyor. 
Bunun niçin:

````sh
mkdir helm-chart
cd helm-chart                       #Chartımızı paketleyeceğimiz klasörü oluşturup oraya geçiyoruz.
helm package ../my-app-chart/      # bir üst klasörde hazırladığımız "my-app-chart" chart klasörünü paketliyoruz. 
helm repo index .                   # helm reposu için gerekli index.yaml dosyasını oluşturuyoruz.
````

## Chart'ın github reposuna gönderilmesi:

````sh
git add .
git commit -m "helm version 1"
git push
````

## Github repomuzdan localimize chartın indirilmesi:

````sh
helm repo ls
helm repo add --username <github-user-name> --password <github-token> <repo-name> '<url the path to the helm-chart folder in the github project as “raw”>'    
# my-url>>>  'githubhttps://raw.githubusercontent.com/Mecit-tuksoy/systemd-docker-k8s-setup/refs/heads/main/k8s/helm-chart'
````

My terminale;
````sh
mecit@Proje:[helm-chart]>(main) helm repo ls
Error: no repositories to show
mecit@Proje:[helm-chart]>(main) helm list
NAME    NAMESPACE       REVISION        UPDATED STATUS  CHART   APP VERSION
mecit@Proje:[helm-chart]>(main) helm repo add --username <github-user-name> --password <github-token> my-repo 'https://raw.githubusercontent.com/Mecit-tuksoy/systemd-docker-k8s-setup/refs/heads/main/k8s/helm-chart'
"my-repo" has been added to your repositories
mecit@Proje:[helm-chart]>(main) helm repo ls
NAME    URL
my-repo https://raw.githubusercontent.com/Mecit-tuksoy/systemd-docker-k8s-setup/refs/heads/main/k8s/helm-chart
mecit@Proje:[helm-chart]>(main) helm search repo my-repo
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
my-repo/my-app-chart    1.0.0           1.0.0           A Helm chart for Kubernetes
````

## "v1" versionun kubernetes kümesine dağıtılması:

````sh
helm install <release-name> <repo-name>          #Uygulamamızın "v1" versionu dağıtılıyor.
````

My terminale;

````sh
mecit@Proje:[helm-chart]>(main) helm install my-release my-repo/my-app-chart
NAME: my-release
LAST DEPLOYED: Sat Jan  4 12:20:10 2025
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Thank you for installing my-app-chart.

Your release is named my-release.

To learn more about the release, try:

  $ helm status my-release
  $ helm get all my-release
mecit@Proje:[helm-chart]>(main) kubectl get pod
NAME                     READY   STATUS    RESTARTS   AGE
my-app-99b7576d7-s4l66   1/1     Running   0          20s
my-app-99b7576d7-xpcvz   1/1     Running   0          20s
mecit@Proje:[helm-chart]>(main) kubectl get pod,ingress
NAME                         READY   STATUS    RESTARTS   AGE
pod/my-app-99b7576d7-s4l66   1/1     Running   0          37s
pod/my-app-99b7576d7-xpcvz   1/1     Running   0          37s

NAME                                       CLASS   HOSTS       ADDRESS   PORTS   AGE
ingress.networking.k8s.io/my-app-ingress   nginx   mecit.com             80      37s
mecit@Proje:[helm-chart]>(main) helm list
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
my-release      default         1               2025-01-04 12:20:10.498226383 +0300 +03 deployed        my-app-chart-1.0.0      1.0.0
mecit@Proje:[helm-chart]>(main) 
mecit@Proje:[helm-chart]>(main) curl mecit.com
Hello from version 1!mecit@Proje:[helm-chart]>(main) 
````

"v1" version başarıyla dağıtıldı. "curl mecit.com" ile sayfamızı gördük.  *"Hello from version 1!"* 

## Uygulamanın "v2" versionlu chart'ının oluşturulup githuba gönderilmesi:


*values.yaml* dosyasındai "tag" değişkenini "v2" yapıyoruz:

````sh
image:
  repository: mecit35/flask-app
  tag: v2
````

Chart'ın içinde bulunan *Chart.yaml* dosyasındaki *"version"* yazan yere ilk çartımız için *"version: 2.0.0"* ve
Chart'ın içinde bulunan *Chart.yaml* dosyasındaki *"appVersion"* yazan yere ilk çartımız için *"appVersion: "2.0.0""* yazıyoruz.

Bu değişikliklerden sonra çartımız hazır. şimdi bu Chartı Github repomuza puşlamamız gerekiyor. 
Bunun niçin:

````sh
helm package ../my-app-chart/      # bir üst klasörde hazırladığımız "my-app-chart" chart klasörünü paketliyoruz. 
helm repo index .                   # helm reposu için gerekli index.yaml dosyasını oluşturuyoruz.
````

## Chart'ın github reposuna gönderilmesi:

````sh
git add .
git commit -m "helm version 2"
git push
````

## Uygulamanın "v2" versionunun Kubernetes kumesine dağıtılması:

````sh
helm list
helm upgrade my-release my-repo/my-app-chart --version 2.0.0
````

My terminale;

````sh
mecit@Proje:[helm-chart]>(main) helm list
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
my-release      default         1               2025-01-04 12:20:10.498226383 +0300 +03 deployed        my-app-chart-1.0.0      1.0.0
mecit@Proje:[helm-chart]>(main) helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "my-repo" chart repository
Update Complete. ⎈Happy Helming!⎈
mecit@Proje:[helm-chart]>(main) helm search repo my-repo
NAME                    CHART VERSION   APP VERSION     DESCRIPTION
my-repo/my-app-chart    2.0.0           2.0.0           A Helm chart for Kubernetes
mecit@Proje:[helm-chart]>(main) helm upgrade my-release my-repo/my-app-chart --version 2.0.0
Release "my-release" has been upgraded. Happy Helming!
NAME: my-release
LAST DEPLOYED: Sat Jan  4 12:45:40 2025
NAMESPACE: default
STATUS: deployed
REVISION: 2
TEST SUITE: None
NOTES:
Thank you for installing my-app-chart.

Your release is named my-release.

To learn more about the release, try:

  $ helm status my-release
  $ helm get all my-release
mecit@Proje:[helm-chart]>(main) kubectl get pod
NAME                      READY   STATUS              RESTARTS   AGE
my-app-7f95895fb8-254wk   0/1     ContainerCreating   0          3s
my-app-7f95895fb8-w7254   0/1     ContainerCreating   0          3s
my-app-99b7576d7-s4l66    1/1     Running             0          25m
my-app-99b7576d7-xpcvz    1/1     Terminating         0          25m
mecit@Proje:[helm-chart]>(main) kubectl get pod
NAME                      READY   STATUS        RESTARTS   AGE
my-app-7f95895fb8-254wk   1/1     Running       0          10s
my-app-7f95895fb8-w7254   1/1     Running       0          10s
my-app-99b7576d7-s4l66    1/1     Terminating   0          25m
my-app-99b7576d7-xpcvz    1/1     Terminating   0          25m
mecit@Proje:[helm-chart]>(main) kubectl get ingress
NAME             CLASS   HOSTS       ADDRESS        PORTS   AGE
my-app-ingress   nginx   mecit.com   192.168.49.2   80      25m
mecit@Proje:[helm-chart]>(main) curl mecit.com
Hello from version 2!mecit@Proje:[helm-chart]>(main) 
mecit@Proje:[helm-chart]>(main) 
````

Uygulamanın *"v2"* version başarıyla dağıtıldı. "curl mecit.com" ile sayfamızı gördük.  *"Hello from version 2!"* 

Uygulamanın *"v2"* versionu Kubernetes kümesine dağıtılırken *"deployment.yaml"* dosyasındaki *"Rolling Update strategy"* kuralına göre bir önceki uygulama versionu ayakta iken sırası ile podların *"Terminate"*  edilerek yeni versionlu podların oluşturulduğu görülmektedir. 


    
## Uygulamanın versionları arasında geçiş yapmak için:

````sh
helm history  my-release
helm rollback my-release 1           #1. release geri dönüş yapılır.
````

Bu aşamadan sonra daha önce dağıtılmış releaselerden isdediğimize geçiş yapabiliriz.

Öreneğin aşağıdaki terminal çıktısında son 10 release içinden istediğime geçiş yapıp istediğim uygulama versionunu dağıtabiliyorum:

````sh
mecit@Proje:[helm-chart]>(main) helm history  my-release
REVISION        UPDATED                         STATUS          CHART                   APP VERSION     DESCRIPTION  
5               Sat Jan  4 13:01:00 2025        superseded      my-app-chart-2.0.0      2.0.0           Rollback to 2
6               Sat Jan  4 13:01:23 2025        superseded      my-app-chart-2.0.0      2.0.0           Rollback to 2
7               Sat Jan  4 13:01:48 2025        superseded      my-app-chart-2.0.0      2.0.0           Rollback to 2
8               Sat Jan  4 13:02:10 2025        superseded      my-app-chart-1.0.0      1.0.0           Rollback to 1
9               Sat Jan  4 13:02:24 2025        superseded      my-app-chart-1.0.0      1.0.0           Rollback to 1
10              Sat Jan  4 13:03:03 2025        superseded      my-app-chart-1.0.0      1.0.0           Rollback to 1
11              Sat Jan  4 13:03:17 2025        superseded      my-app-chart-2.0.0      2.0.0           Rollback to 2
12              Sat Jan  4 13:05:48 2025        superseded      my-app-chart-2.0.0      2.0.0           Rollback to 2
13              Sat Jan  4 13:06:42 2025        superseded      my-app-chart-2.0.0      2.0.0           Rollback to 5
14              Sat Jan  4 13:07:08 2025        deployed        my-app-chart-1.0.0      1.0.0           Rollback to 9
mecit@Proje:[helm-chart]>(main) helm rollback my-release 9
Rollback was a success! Happy Helming!
mecit@Proje:[helm-chart]>(main) curl mecit.com
Hello from version 1!mecit@Proje:[helm-chart]>(main) 
mecit@Proje:[helm-chart]>(main) helm history  my-release
REVISION        UPDATED                         STATUS          CHART                   APP VERSION     DESCRIPTION  
6               Sat Jan  4 13:01:23 2025        superseded      my-app-chart-2.0.0      2.0.0           Rollback to 2
7               Sat Jan  4 13:01:48 2025        superseded      my-app-chart-2.0.0      2.0.0           Rollback to 2
8               Sat Jan  4 13:02:10 2025        superseded      my-app-chart-1.0.0      1.0.0           Rollback to 1
9               Sat Jan  4 13:02:24 2025        superseded      my-app-chart-1.0.0      1.0.0           Rollback to 1
10              Sat Jan  4 13:03:03 2025        superseded      my-app-chart-1.0.0      1.0.0           Rollback to 1
11              Sat Jan  4 13:03:17 2025        superseded      my-app-chart-2.0.0      2.0.0           Rollback to 2
12              Sat Jan  4 13:05:48 2025        superseded      my-app-chart-2.0.0      2.0.0           Rollback to 2
13              Sat Jan  4 13:06:42 2025        superseded      my-app-chart-2.0.0      2.0.0           Rollback to 5
14              Sat Jan  4 13:07:08 2025        superseded      my-app-chart-1.0.0      1.0.0           Rollback to 9
15              Sat Jan  4 13:11:41 2025        deployed        my-app-chart-1.0.0      1.0.0           Rollback to 9
mecit@Proje:[helm-chart]>(main) helm rollback my-release 12
Rollback was a success! Happy Helming!
mecit@Proje:[helm-chart]>(main) curl mecit.com
Hello from version 2!mecit@Proje:[helm-chart]>(main) 
mecit@Proje:[helm-chart]>(main) 
````

##  Yoğun Trafik Testi ve HPA’nın Tetiklenmesi

Kubernetes Cluster'da HPA'nın çalışması için metrics-server bileşenini kurmanız gerekir. Kubernetes, podların CPU ve bellek kullanımını bu bileşen üzerinden toplar.
````sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
````

while true döngüsü ile yük testi yapmak için;

````sh
while true; do curl -s http://mecit.com > /dev/null; done
````

kaynakları kontrol ettiğimizde;

````sh
mecit@Proje:[Konzek]> kubectl get pod
NAME                      READY   STATUS    RESTARTS   AGE
my-app-65cbc49475-hx99q   1/1     Running   0          3m21s
my-app-65cbc49475-xp2rs   1/1     Running   0          3m20s
mecit@Proje:[Konzek]> kubectl get hpa
NAME         REFERENCE           TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
my-app-hpa   Deployment/my-app   45%/50%   2         10        2          6m4s
mecit@Proje:[Konzek]> kubectl get pods
NAME                      READY   STATUS    RESTARTS   AGE
my-app-65cbc49475-hx99q   1/1     Running   0          4m38s
my-app-65cbc49475-mhqmd   1/1     Running   0          17s
my-app-65cbc49475-r5v5p   1/1     Running   0          17s
my-app-65cbc49475-xp2rs   1/1     Running   0          4m37s
mecit@Proje:[Konzek]> kubectl get hpa
NAME         REFERENCE           TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
my-app-hpa   Deployment/my-app   145%/50%   2         10        4          7m9s
mecit@Proje:[Konzek]> kubectl get pods
NAME                      READY   STATUS    RESTARTS   AGE
my-app-65cbc49475-4mh9j   1/1     Running   0          16s
my-app-65cbc49475-5f5sx   1/1     Running   0          16s
my-app-65cbc49475-hx99q   1/1     Running   0          6m50s
my-app-65cbc49475-lvhm8   1/1     Running   0          17s
my-app-65cbc49475-mhqmd   1/1     Running   0          2m29s
my-app-65cbc49475-nvkkr   1/1     Running   0          16s
my-app-65cbc49475-r5v5p   1/1     Running   0          2m29s
my-app-65cbc49475-t6nzh   1/1     Running   0          2m11s
my-app-65cbc49475-xp2rs   1/1     Running   0          6m49s
my-app-65cbc49475-zh7g7   1/1     Running   0          2m11s
````

Döngüyü sonlandırdıktan sonra kaynakların durumu:

````sh
mecit@Proje:[Konzek]> kubectl get hpa
NAME         REFERENCE           TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
my-app-hpa   Deployment/my-app   78%/50%   2         10        10         9m25s
mecit@Proje:[Konzek]> kubectl get hpa
NAME         REFERENCE           TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
my-app-hpa   Deployment/my-app   22%/50%   2         10        10         11m
mecit@Proje:[Konzek]> kubectl get hpa
NAME         REFERENCE           TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
my-app-hpa   Deployment/my-app   2%/50%    2         10        10         12m
mecit@Proje:[Konzek]> kubectl get pods
NAME                      READY   STATUS    RESTARTS   AGE
my-app-65cbc49475-mhqmd   1/1     Running   0          10m
my-app-65cbc49475-r5v5p   1/1     Running   0          10m
my-app-65cbc49475-t6nzh   1/1     Running   0          10m
my-app-65cbc49475-xp2rs   1/1     Running   0          14m
my-app-65cbc49475-zh7g7   1/1     Running   0          10m
mecit@Proje:[Konzek]> kubectl get pods
NAME                      READY   STATUS        RESTARTS   AGE
my-app-65cbc49475-mhqmd   1/1     Running       0          11m
my-app-65cbc49475-r5v5p   1/1     Running       0          11m
my-app-65cbc49475-t6nzh   0/1     Terminating   0          11m
my-app-65cbc49475-xp2rs   0/1     Terminating   0          15m
my-app-65cbc49475-zh7g7   1/1     Terminating   0          11m
mecit@Proje:[Konzek]> kubectl get pods
NAME                      READY   STATUS    RESTARTS   AGE
my-app-65cbc49475-mhqmd   1/1     Running   0          11m
my-app-65cbc49475-r5v5p   1/1     Running   0          11m
````
