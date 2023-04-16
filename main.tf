# Create VPC
# terraform aws create vpc
resource "aws_vpc" "setu_vpc" {
  cidr_block           = var.vpc-cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "Setu VPC"
  }
}

# Create Internet Gateway and Attach it to VPC
# terraform aws create internet gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.setu_vpc.id

  tags = {
    Name = "Internet Gateway"
  }
}

# Create Public Subnet 1
# terraform aws create subnet
resource "aws_subnet" "public-subnet-1" {
  vpc_id                  = aws_vpc.setu_vpc.id
  cidr_block              = var.public-subnet-cidr
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet 1"
  }
}

# Create Route Table and Add Public Route
# terraform aws create route table
resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.setu_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

# Associate Public Subnet to "Public Route Table"
# terraform aws associate subnet with route table
resource "aws_route_table_association" "public-subnet-1-route-table-association" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.public-route-table.id
}

# Create Private Subnet 1
# terraform aws create subnet
resource "aws_subnet" "private-subnet-1" {
  vpc_id                  = aws_vpc.setu_vpc.id
  cidr_block              = var.private-subnet-1-cidr
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet 1 | App Tier"
  }
}


# Create Private Subnet 2
# terraform aws create subnet
resource "aws_subnet" "private-subnet-2" {
  vpc_id                  = aws_vpc.setu_vpc.id
  cidr_block              = var.private-subnet-2-cidr
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "Private Subnet 2 | Database Tier"
  }
}

# Editing the default Security Group of the VPC to allow every traffic
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.setu_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "nat_gateway" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.public-subnet-1.id
  tags = {
    "Name" = "Nat Gateway"
  }
}

resource "aws_route_table" "nat_route_table" {
  vpc_id = aws_vpc.setu_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "private_subnet_1_nat_rt_association" {
  subnet_id      = aws_subnet.private-subnet-1.id
  route_table_id = aws_route_table.nat_route_table.id
}

resource "aws_route_table_association" "private_subnet_2_nat_rt_association" {
  subnet_id      = aws_subnet.private-subnet-2.id
  route_table_id = aws_route_table.nat_route_table.id
}

resource "aws_security_group" "db_sg" {

  description = "Security Group for Database"
  name        = "db_sg"
  vpc_id      = aws_vpc.setu_vpc.id

  ingress {
    description     = "Allow ingress mysql connections from private app boxes only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.private_app_sg.id]
  }

  ingress {
    description     = "Allow ingress ssh connections from private app boxes only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.private_app_sg.id]
  }

  egress {
    description = "Allow all egress from DB box"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "private_app_sg" {

  description = "Security Group for Private App 1 and 2"
  name        = "private_app_sg"
  vpc_id      = aws_vpc.setu_vpc.id

  ingress {
    description = "Allow ingress http connections from the whole VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Allow ingress ping connections from the whole VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "ICMP"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "Allow ingress ssh connections from the whole VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Allow all egress from Private box"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "public_app_sg" {

  description = "Security Group for Public App"
  name        = "public_app_sg"
  vpc_id      = aws_vpc.setu_vpc.id

  ingress {
    description = "Allow ingress http connections from everywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ingress ping connections from everywhere"
    from_port   = 0
    to_port     = 0
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ingress ssh connections from everywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all egress from Private box"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



