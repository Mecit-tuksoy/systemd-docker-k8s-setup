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

## Creating Helm Chart:

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
