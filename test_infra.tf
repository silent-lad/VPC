# All this Infra is not part of the VPC setuo but just the instances running on the VPC created in main.tf

# Creatng SSH keys to debug into the private boxes as they are not available through ec2 connect because of not having a public IP
resource "aws_key_pair" "ssh_keys" {
  key_name   = "ssh_keys"
  public_key = file("keys/key.pub")
}

# Using aws AMI data source to get AMI for our VMs
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Creating first microservice
# In public subnet
# Associated to public security group
# Accesible bot inside and outside VPC
resource "aws_instance" "public_microservice" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public-subnet-1.id
  key_name      = "ssh_keys"

  vpc_security_group_ids = [aws_security_group.public_app_sg.id]

  depends_on = [
    aws_instance.private_microservice_1,
    aws_instance.private_microservice_2
  ]

  user_data = <<-EOF
              #!/bin/bash
              echo "Making a curl request to the second EC2 instance"
              sudo apt update -y
              sudo apt install apache2 mysql-server -y
              sudo chown -R $USER:$USER /var/www
              DB_RESPONSE=$(timeout 5 mysql -h ${aws_instance.mock_db_service.private_ip} -u root -proot -e "SELECT 1;" || echo "DB Not reachable")
              echo "-- Hello, World! from PUBLIC MICROSERVICE --" > /var/www/html/index.html
              echo "</br>" >> /var/www/html/index.html
              echo "-----------------" >> /var/www/html/index.html
              echo "</br>" >> /var/www/html/index.html
              echo "-- RESPONSE FROM MICROSERVICE 1: --" >> /var/www/html/index.html
              echo "</br>">> /var/www/html/index.html
              echo $(curl http://${aws_instance.private_microservice_1.private_ip}:80) >> /var/www/html/index.html
              echo "</br>" >> /var/www/html/index.html
              echo "------------------" >> /var/www/html/index.html
              echo "</br>" >> /var/www/html/index.html
              echo "-- RESPONSE FROM MICROSERVICE 2: --" >> /var/www/html/index.html
              echo "</br>" >> /var/www/html/index.html
              echo $(curl http://${aws_instance.private_microservice_2.private_ip}:80) >> /var/www/html/index.html
              echo "</br>" >> /var/www/html/index.html
              echo "-----------------" >> /var/www/html/index.html
              echo "</br>" >> /var/www/html/index.html
              echo "RESPONSE FROM INTERNAL DATABASE TO PUBLIC MICROSERVICE:" >> /var/www/html/index.html
              echo "</br>" >> /var/www/html/index.html
              echo $DB_RESPONSE >> /var/www/html/index.html
              echo "</br>" >> /var/www/html/index.html
              echo "-----------------" >> /var/www/html/index.html
              sudo systemctl start apache2.service
              EOF

  tags = {
    Name = "Microservice 1 accesible by public internet"
  }
}


# Creating second microservice (Private)
# In private subnet
# Associated to private app security group
# Accesible only inside the VPC and not from internet.
resource "aws_instance" "private_microservice_1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private-subnet-1.id
  key_name               = "ssh_keys"
  vpc_security_group_ids = [aws_security_group.private_app_sg.id]

  depends_on = [
    aws_instance.mock_db_service
  ]

  user_data = <<-EOF
                #!/bin/bash
                echo "Making a test DB request to the mock DB instance"
                sudo apt install apache2 mysql-server -y
                sudo chown -R $USER:$USER /var/www
                DB_RESPONSE=$(timeout 5 mysql -h ${aws_instance.mock_db_service.private_ip} -u root -proot -e "SELECT 1;" || echo "DB Not reachable")
                echo "> Hello, World! from private microservice 1" > /var/www/html/index.html
                echo "</br>" >> /var/www/html/index.html
                echo "> RESPONSE FROM INTERNAL DATABASE TO PRIVATE MICROSERVICE 1: for query SELECT 1" >> /var/www/html/index.html
                echo "</br>" >> /var/www/html/index.html
                echo $DB_RESPONSE >> /var/www/html/index.html
                sudo systemctl start apache2.service
                EOF

  tags = {
    Name = "Private Microservice 1"
  }
}


# Creating thrid microservice (Private)
# In private subnet
# Associated to private app security group
# Accesible only inside the VPC and not from internet.
resource "aws_instance" "private_microservice_2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private-subnet-1.id
  key_name               = "ssh_keys"
  vpc_security_group_ids = [aws_security_group.private_app_sg.id]

  depends_on = [
    aws_instance.mock_db_service
  ]

  user_data = <<-EOF
                #!/bin/bash
                echo "Making a test DB request to the mock DB instance"
                sudo apt install apache2 mysql-server -y
                sudo chown -R $USER:$USER /var/www
                sudo systemctl start apache2.service
                DB_RESPONSE=$(timeout 5 mysql -h ${aws_instance.mock_db_service.private_ip} -u root -proot -e "SELECT 1;" || echo "DB Not reachable")
                echo "> Hello, World! from private microservice 2" > /var/www/html/index.html
                echo "</br>" >> /var/www/html/index.html
                echo "> RESPONSE FROM INTERNAL DATABASE TO PRIVATE MICROSERVICE 2: for query SELECT 1" >> /var/www/html/index.html
                echo "</br>" >> /var/www/html/index.html
                echo $DB_RESPONSE >> /var/www/html/index.html
                sudo systemctl start apache2.service
                EOF

  tags = {
    Name = "Private Microservice 2"
  }
}

# Creating second microservice (Private)
# In private subnet
# Associated to private app security group
# Accesible only inside the VPC and not from internet.
# Only accesible by the 2 PRIVATE microservics (Or whatever has application private SG attached to it) and not the public microservice
resource "aws_instance" "mock_db_service" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = "ssh_keys"
  subnet_id              = aws_subnet.private-subnet-2.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  user_data = file("bin/database.sh")

  tags = {
    Name = "Mock Database"
  }
}