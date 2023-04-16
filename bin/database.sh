#! /bin/bash
sudo apt update
sudo apt install docker.io -y
sudo systemctl restart docker
sudo systemctl enable docker
sudo docker pull mysql
sudo docker run --name mysql -e MYSQL_ROOT_PASSWORD=root \
-e MYSQL_DATABASE=db -p 3306:3306 -d mysql:5.7