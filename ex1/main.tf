terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.74.0"
      
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}


// CORE VPC
resource "aws_vpc" "mainVPC" {
  cidr_block        = "10.0.0.0/20"
  instance_tenancy  = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "main"
  }
}

// Subnet1
resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.mainVPC.id
  cidr_block = "10.0.0.0/26"

  tags = {
    Name = "subnet1"
  }
}

//Subnet2
resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.mainVPC.id
  cidr_block = "10.0.2.0/26"

  tags = {
    Name = "subnet2"
  }
}

//IG
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.mainVPC.id

  tags = {
    Name = "gw"
  }
}

// Route Table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.mainVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "rt"
  }
}

resource "aws_network_interface" "interface1" {
   subnet_id       = aws_subnet.subnet1.id
   private_ips     = ["10.0.0.20"]
   security_groups = [aws_security_group.allow_tls.id]
}

// Interface subnet 2
resource "aws_network_interface" "interface2" {
  subnet_id       = aws_subnet.subnet2.id
  private_ips     = ["10.0.2.20"]
  security_groups = [aws_security_group.allow_tls.id]
}

// add elastic IP to int1
resource "aws_eip" "eip1" {
  vpc                       = true
  network_interface         = aws_network_interface.interface1.id
  associate_with_private_ip = "10.0.0.20"
  depends_on                = [aws_internet_gateway.gw]
}

// add elastic IP to int1
resource "aws_eip" "eip2" {
  vpc                       = true
  network_interface         = aws_network_interface.interface2.id
  associate_with_private_ip = "10.0.2.20"
  depends_on                = [aws_internet_gateway.gw]
}


// routing ass1
resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}

// routing ass2
resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.mainVPC.id

  ingress {
    description      = "HTTP port"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH port"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

// T2.micro instance
resource "aws_instance" "instance1" {
  ami           = var.ami
  instance_type = var.instance
  key_name      = var.keyname
  
  tags = {
    Name = "instance1"
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.interface1.id
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    sudo systemctl start nginx
    echo "It works :)"
  EOF
}

// T2.micro instance
resource "aws_instance" "instance2" {
  ami           = var.ami
  instance_type = var.instance
  key_name      = var.keyname
  
  tags = {
    Name = "instance2"
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.interface2.id
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    sudo systemctl start nginx
    echo "It works :)"
  EOF
}
