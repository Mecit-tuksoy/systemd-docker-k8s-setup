### In order to complete the tasks outlined in this document, the following system requirements must be met:

System Requirements:

1- Operating System: Ubuntu 22.04.5 LTS or a compatible Linux distribution.

2- Programming Languages: Python 3, pip3

3- Containerization: Docker, Docker Compose

4- Orchestration: Kubernetes (minikube, KIND, EKS, or a managed Kubernetes service)

5- CLI Tools: kubectl, Helm, talosctl


# Task 1

The purpose of this task is to run a Python Flask application that prints "Hello everyone!" as a systemd service on Ubuntu. The service should remain active, ensure logs are recorded correctly, and automatically restart in case of potential errors.

````sh
python3 --version           #Check if python3 is installed. If not, install it using the following command:
sudo apt update && sudo apt install python3
which python3               #Find the path of python3 to use it in the service file.
pwd                         #Get the current directory path where the application is located, to use it in the service file.
whoami                      # to find out who the user is
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
sudo systemctl status myapp.service  # Check the service status
````


# Task 2

To install docker and docker compose we can run the docker.sh file in the scripts folder.

````sh
docker version
docker compose version
````

We copy the app.py application file and requirements.txt file into the task2 folder.
````sh
cd ..
mkdir docker
cd docker
cp /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/systemd/app.py .
cp /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/systemd/requirements.txt .
````

We create the Dockerfile.

````sh
FROM python:3.9-slim
WORKDIR /app
COPY . /app
RUN pip install -r requirements.txt
EXPOSE 8080
CMD ["python", "app.py"]

````

We create the docker-compose.yml file to run the application.

```sh
version: '3.8'
services:
  app:
    image: task2-app:latest
    deploy:
      replicas: 2
      restart_policy:
        condition: any
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

```


We create an nginx.conf file to include in the Nginx image (as specified in the compose file).

````sh
events {
    worker_connections 1024; 
}

http {
    upstream app_servers {
        server app:8080; # Target the Flask application container
    }

    server {
        listen 80;

        location / {
            proxy_pass http://app_servers;
        }
    }
}

````

To deploy the application:

````sh
docker build -t task2-app .                #We run this command while in the docker folder to create the image.
docker swarm init --advertise-addr 172.19.51.62     #We start Docker Swarm with the specified IP.
docker stack deploy -c docker-compose.yml konzek-stack    #We deploy the application.
docker service ls                                         #We can see the services deployed successfully.
docker ps -a                                             #We can see the running and stopped containers.
docker rm -f <container id>                              #We can stop a running container and check whether it is recreated or not.
docker stack rm konzek-stack                          #Stops and removes all services and networks associated with the stack.
docker swarm leave --force       #Removes the current node from Swarm mode, and no new containers will be created in Swarm mode anymore.
````
From the terminal:

````sh
mecit@Proje:[docker]>(main) docker stack deploy -c docker-compose.yml konzek-stack
Since --detach=false was not specified, tasks will be created in the background.
In a future release, --detach=false will become the default.
Creating network konzek-stack_app_network
Creating service konzek-stack_nginx
Creating service konzek-stack_app

mecit@Proje:[docker]>(main) docker service ls
ID             NAME                 MODE         REPLICAS   IMAGE              PORTS
wnb62d04d7w1   konzek-stack_app     replicated   2/2        task2-app:latest
t2n43nrbsdd3   konzek-stack_nginx   replicated   1/1        nginx:latest       *:80->80/tcp

mecit@Proje:[docker]>(main) docker ps -a
CONTAINER ID   IMAGE                                 COMMAND                  CREATED          STATUS                      PORTS                                  
                                                                                                NAMES
a067d623f638   nginx:latest                          "/docker-entrypoint.…"   7 seconds ago    Up 2 seconds                80/tcp                                 
                                                                                                konzek-stack_nginx.1.539z91e7361ji7aaimj3o0beb
33896e5112bc   task2-app:latest                      "python app.py"          14 seconds ago   Up 13 seconds               8080/tcp                               
                                                                                                konzek-stack_app.2.qn3mzb09cxjgcny5ymrrn09gp
9f3d1357ecd6   task2-app:latest                      "python app.py"          14 seconds ago   Up 13 seconds               8080/tcp                               
                                                                                                konzek-stack_app.1.ioc5xszcynqunwrqhzjsadqpj
666fc78f6466   nginx:latest                          "/docker-entrypoint.…"   18 seconds ago   Exited (1) 8 seconds ago                                           
                                                                                                konzek-stack_nginx.1.yrev2y4wd6dpecgiezq5vud5p

mecit@Proje:[docker]>(main) curl 172.19.51.62
Hello Konzek!

mecit@Proje:[docker]>(main) docker rm -f 33896e5112bc 9f3d1357ecd6 
33896e5112bc
9f3d1357ecd6

mecit@Proje:[docker]>(main) docker ps -a
CONTAINER ID   IMAGE                                 COMMAND                  CREATED         STATUS                      PORTS                                   
                                                                                               NAMES
1599aacd8f61   task2-app:latest                      "python app.py"          1 second ago    Created                                                             
                                                                                               konzek-stack_app.2.wafyya9057ow3cwfdjvdbwa16
572ef56c7d3d   task2-app:latest                      "python app.py"          1 second ago    Created                                                             
                                                                                               konzek-stack_app.1.eh6tolrpkellvsb3e4pmyoool
a067d623f638   nginx:latest                          "/docker-entrypoint.…"   2 minutes ago   Up 2 minutes                80/tcp                                  
                                                                                               konzek-stack_nginx.1.539z91e7361ji7aaimj3o0beb
666fc78f6466   nginx:latest                          "/docker-entrypoint.…"   2 minutes ago   Exited (1) 2 minutes ago                                            
                                                                                               konzek-stack_nginx.1.yrev2y4wd6dpecgiezq5vud5p
mecit@Proje:[docker]>(main) curl 172.19.51.62
Hello Konzek!
````



# Task 3

## We copy the app.py application file, requirements.txt, and Dockerfile into the k8s directory under the my-app-version1 and my-app-version2 folders.

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

In the app.py application in the my-app-version1 folder, we change the text "Hello everyone!" to "Hello from version 1!" and 
in the app.py application in the my-app-version2 folder, we change the text "Hello everyone!" to "Hello from version 2!".

## We are constructing a Docker image and uploading it to the Docker Hub registry.

By executing the following commands in the "my-app-version1" directory, we are pushing version v1 of the application to Docker Hub.
````sh
docker build -t mecit35/flask-app:v1 .
docker login
docker push mecit35/flask-app:v1
````
By executing the following commands in the "my-app-version2" directory, we are pushing version v2 of the application to Docker Hub.
````sh
docker build -t mecit35/flask-app:v2 .
docker login
docker push mecit35/flask-app:v2
````

## Creating Kubernetes manifests:

We create the following manifest files: HorizontalPodAutoscaler, Deployment, Service, and Ingress to deploy applications to Kubernetes.

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

To enable the Horizontal Pod Autoscaler (HPA) in your Kubernetes cluster, you need to install the metrics-server component. 
Kubernetes collects CPU and memory usage data from pods using this component.

````sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
````

ingress controller kurmak için:

````sh
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
kubectl create namespace ingress-namespace
helm install nginx-ingress ingress-nginx/ingress-nginx -n ingress-namespace

````


## Creating Helm Chart:


Helm yüklü değilse yüklemek için :

````sh
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

helm version  
````

For creating a chart:

````sh
helm create my-app-chart
rm -rf my-app-chart/templates/*   #We are removing manifest files from the templates directory.
````

The Kubernetes files created above are being moved to the my-app-chart/templates/ location.

We are clearing the contents of the values.yaml file within the chart and adding the following variable:

````sh
image:
  repository: mecit35/flask-app
  tag: v1
````

We are updating the 'version' field in the Chart.yaml file to '1.0.0' for our first chart.
We are assigning 'appVersion: "1.0.0"' to the 'appVersion' field in the Chart.yaml file for our first chart.

After making these changes, our chart is ready. Now we need to push this chart to our GitHub repository.
For this: 

````sh
mkdir helm-chart
cd helm-chart                       
helm package ../my-app-chart/       # Package the "my-app-chart" chart located in the parent directory.
helm repo index .                  # Create an index.yaml file for the Helm repository.
````

## Pushing the chart to the GitHub repository:

````sh
git add .
git commit -m "helm version 1"
git push
````

## Downloading the chart from our GitHub repository to our local machine:

````sh
helm repo ls
helm repo add --username <github-user-name> --password <github-token> <repo-name> '<url the path to the helm-chart folder in the github project as “raw”>'    
# my-url>>>  'githubhttps://raw.githubusercontent.com/Mecit-tuksoy/systemd-docker-k8s-setup/refs/heads/main/k8s/helm-chart'
````

From the my terminale;
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

## Deploying version "v1" to the Kubernetes cluster:

````sh
helm install <release-name> <repo-name>         
````

From the my terminale;

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

The deployment was successful "v1". We were able to access the page by running 'curl mecit.com'.  *"Hello from version 1!"* 


## Building and uploading the v2 chart to the GitHub repository:

We are changing the 'tag' value to 'v2' in *values.yaml*:
````sh
image:
  repository: mecit35/flask-app
  tag: v2
````

For our second chart, we're setting the 'version' and 'appVersion' fields in the Chart.yaml file to '2.0.0'. 
This indicates that this is the second version of both the chart itself and the application it represents.

Once we've made these changes, our chart is ready for deployment. The next step is to push this updated chart to our GitHub repository.

````sh
helm package ../my-app-chart/     
helm repo index .                   
````

## Pushing the chart to the GitHub repository:

````sh
git add .
git commit -m "helm version 2"
git push
````

## Rolling out the v2 version of the application on Kubernetes:

````sh
helm list
helm upgrade my-release my-repo/my-app-chart --version 2.0.0
````

From the My terminale;
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

Deployment of the application's v2 version was successful. We confirmed this by successfully curling mecit.com.  *"Hello from version 2!"* 

The deployment of the application's v2 version adhered to the rolling update strategy outlined in the deployment.yaml file. 
This resulted in a gradual replacement of the old version's pods with new v2 pods, ensuring minimal downtime.

    
## Rolling back to a previous version:

````sh
helm history  my-release
helm rollback my-release 1          
````

From this point forward, we can switch to any of the previously deployed releases.

The terminal output demonstrates that we can switch to any of the last 10 releases and deploy the desired application version.
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

##  Stress testing and HPA scaling

Performing a load test using a while true loop:

````sh
while true; do curl -s http://mecit.com > /dev/null; done
````

When we checked the resources:

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

State of pods after loop termination:
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


# Task 4 (systemd Service Troubleshooting)

Incorrectly configured systemd file:

````sh
[Unit]
Description=MyApp Service
After=network.target

[Service]
ExecStart=/usr/local/lib/python3 /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/systemd/app.py
WorkingDirectory=/mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/systemd
Restart=always
StandardOutput=file:/var/log/myapp.log
StandardError=file:/var/log/myapp-error.log
User=ubuntu

[Install]
WantedBy=multi-user.target
````

## Step 1:
Before creating the service file in its correct location, I manually test the steps. For this:

I check whether the Python3 path and application path specified in ExecStart are correct.

````sh
mecit@Proje:[troubleshooting]>(main) which python3
/usr/bin/python3                      # The path in the file is given as "/usr/local/lib/python3".

````sh
mecit@Proje:[troubleshooting]>(main) ls /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/systemd | grep app.py 
app.py                                 # This path appears to be correct.
````

## step 2:

I check the location and content of the app.py application specified in the path. If the necessary dependencies are not installed, I collaborate with the application developer to install the required packages.

````sh
mecit@Proje:[systemd]>(main) cat /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/systemd/app.py
from flask import Flask               # Required for the application to run
app = Flask(__name__)

@app.route('/')
def home():
    return "Hello everyone!"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
````

Seeing that the requirements.txt file in the same directory contains Flask, I check whether Flask is installed on my system.

````sh
mecit@Proje:[systemd]>(main) pip list | grep Flask
Flask               3.1.0                          # Flask is installed.
````

## Step 3:

I run the application manually from its own location to verify it works.

````sh
mecit@Proje:[systemd]>(main) /usr/bin/python3 /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/systemd/app.py
 * Serving Flask app 'app'
 * Debug mode: off
WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:5000
 * Running on http://172.19.51.62:5000
Press CTRL+C to quit
127.0.0.1 - - [05/Jan/2025 17:56:35] "GET / HTTP/1.1" 200 -
````

````sh
mecit@Proje:[Konzek]> curl http://127.0.0.1:5000
Hello everyone! 
````
The application worked successfully.

## Step 4:

According to the service file, the user that will run this service is User=ubuntu. I check whether this user exists and verify the read, write, and execute permissions for the log files /var/log/myapp.log and /var/log/myapp-error.log.

````sh
mecit@Proje:[Konzek]> whoami
mecit  # The current active user.
mecit@Proje:[Konzek]> ls -l /var/log | grep myapp-error.log
-rw-r--r--  1 root      root       793 Jan  5 14:09 myapp-error.log  # The file ownership belongs to the root user.
mecit@Proje:[Konzek]> ls -l /var/log | grep myapp.log
-rw-r--r--  1 root      root        46 Jan  4 19:48 myapp.log  # The file ownership belongs to the root user.
mecit@Proje:[Konzek]> sudo chown mecit:mecit /var/log/myapp.log /var/log/myapp-error.log  # Change ownership to the 'mecit' user.
mecit@Proje:[Konzek]> ls -l /var/log | grep myapp.log
-rw-r--r--  1 mecit     mecit       46 Jan  4 19:48 myapp.log  # Ownership changed to the 'mecit' user.
mecit@Proje:[Konzek]> ls -l /var/log | grep myapp-error.log
-rw-r--r--  1 mecit     mecit      793 Jan  5 14:09 myapp-error.log  # Ownership changed to the 'mecit' user.
````
The -rw-r--r-- permissions indicate that the file owner has read and write permissions.


## Step 5:

I create the modified service file under /etc/systemd/system, then start and enable the service. Finally, I check the logs to ensure the service is running as expected.

````sh
sudo nano /etc/systemd/system/myapp.service  
sudo systemctl daemon-reload
sudo systemctl start myapp.service
sudo systemctl enable myapp.service
# Checking logs:
cat /var/log/myapp-error.log
sudo systemctl status myapp.service  # Check the service status
````

Logs and Service Status:
````sh
mecit@Proje:[Konzek]> sudo systemctl start myapp.service
mecit@Proje:[Konzek]> sudo systemctl enable myapp.service
Created symlink /etc/systemd/system/multi-user.target.wants/myapp.service → /etc/systemd/system/myapp.service.
mecit@Proje:[Konzek]> cat /var/log/myapp-error.log
WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:5000
 * Running on http://172.19.51.62:5000
Press CTRL+C to quit
127.0.0.1 - - [04/Jan/2025 19:48:31] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [04/Jan/2025 19:48:33] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [04/Jan/2025 19:48:34] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [05/Jan/2025 12:37:59] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [05/Jan/2025 12:38:00] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [05/Jan/2025 12:38:00] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [05/Jan/2025 12:39:02] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [05/Jan/2025 12:39:03] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [05/Jan/2025 14:09:26] "GET / HTTP/1.1" 200 -
mecit@Proje:[Konzek]> sudo systemctl status myapp.service
● myapp.service - MyApp Service
     Loaded: loaded (/etc/systemd/system/myapp.service; enabled; vendor preset: enabled)
     Active: active (running) since Mon 2025-01-06 11:38:02 +03; 25s ago
   Main PID: 2027 (python3)
      Tasks: 1 (limit: 3468)
     Memory: 24.3M
     CGroup: /system.slice/myapp.service
             └─2027 /usr/bin/python3 /mnt/c/Users/MCT/Desktop/Konzek/systemd-docker-k8s-setup/systemd/app.py

Jan 06 11:38:02 SERHAT systemd[1]: Started MyApp Service.
mecit@Proje:[Konzek]> 
````


# Task 5 Talos:

Talos'un **https://www.talos.dev/v1.9/talos-guides/install/local-platforms/virtualbox/** sayfasındaki dökümanı takip ederek VirtualBox VM'leri ile Talos Kubernetes kümesi oluşturdum:

TalosCTL Kurulumu:

````sh
curl -Lo /usr/local/bin/talosctl https://github.com/siderolabs/talos/releases/download/v1.4.0/talosctl-linux-amd64
chmod +x /usr/local/bin/talosctl
````

iso dosyasını indirmek için:

````sh
mkdir -p _out/

curl https://factory.talos.dev/image/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba/v1.9.0/metal-amd64.iso -L -o _out/metal-amd64.iso
````

VirtualBox kullanıcı arayüzündeki “Yeni ” düğmesini tıklayarak yeni bir VM oluşturuyoruz. VM için bir ad verip dosya sistemimizden indirdiğimiz  ISO'yu seçiyoruz ve Tür ve Sürümü belirtiyoruz. VM için en az 2 GB RAM ve en az 2 CPU sağlıyoruz. 
Oluşturulduktan sonra VM'yi seçip ve “Ayarlar ” >> “Ağ ” >> “Ekli ağ ” >> “Köprülü Adaptör ” olarak değiştiriyoruz.






export CONTROL_PLANE_IP=192.168.1.135

export WORKER_IP=192.168.1.107



````sh
talosctl -n 192.168.1.135 health      # Talos node'larının sağlığını kontrol et

talosctl -n $CONTROL_PLANE_IP get nodes     # Talos node'larını  Ready durumda olup olmadığını kontrol et.

talosctl -n $CONTROL_PLANE_IP bootstrap     # Talos cluster'ını bootstrap yap

nc -zv 192.168.1.135 6443     # Güvenlik duvarını ve port erişimini test et

talosctl -n 192.168.1.135 service kube-apiserver  # API sunucusunun sağlıklı olup olmadığını kontrol etmek için

talosctl -n 192.168.1.135 service kube-apiserver restart   # Servisi Yeniden Başlat için

talosctl -n 192.168.1.135 kubeconfig .kubeconfig          # Talos cluster’ına erişmek için kubeconfig dosyasını indiriyor

cat ./kubeconfig              # Kubeconfig dosyasını doğrula

kubectl --kubeconfig=./kubeconfig get nodes      #kubectl komutu ile node kontrole et.

export KUBECONFIG=$(pwd)/kubeconfig     # bulunduğum dizindeki kubeconfig dosyasını varsayılan yapılandırma olarak ayarlamak için

````

````sh
mecit@Proje:[Konzek]> kubectl get nodes
NAME            STATUS   ROLES           AGE     VERSION
talos-084-2wg   Ready    control-plane   3h11m   v1.32.0
talos-xfo-wra   Ready    <none>          3h11m   v1.32.0
````


To enable the Horizontal Pod Autoscaler (HPA) in your Kubernetes cluster, you need to install the metrics-server component. 
Kubernetes collects CPU and memory usage data from pods using this component.

````sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
````

ingress controller kurmak için:

````sh
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml
````


Github repomuzdaki chart'ı local repoya ekliyip uygulamayı clustera deploy etmek için:

````sh
helm repo ls
helm repo add --username <github-user-name> --password <github-token> <repo-name> '<url the path to the helm-chart folder in the github project as “raw”>'    
# my-url>>>  'githubhttps://raw.githubusercontent.com/Mecit-tuksoy/systemd-docker-k8s-setup/refs/heads/main/k8s/helm-chart'

helm repo ls

helm search repo my-repo

helm install my-release my-repo/my-app-chart


````





mecit@Proje:[Konzek]> curl http://192.168.1.107:30326/
Hello from version 2!

