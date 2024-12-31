# Task 1

````sh
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
uygulamamız 8080 portunda çalışacağı için sisteminizdeki portları kontrol edioruz. 
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