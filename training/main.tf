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

# 1. Create vpc

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "IGateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "IGateway"
  }
}

# 3. Create Custom Route Table

resource "aws_route_table" "mainRoute" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGateway.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.IGateway.id
  }

  tags = {
    Name = "routeTable"
  }

}

# 4. Create a Subnet 

resource "aws_subnet" "mainSubnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "mainSubnet"
  }
}

# 5. Associate subnet with Route Table

resource "aws_route_table_association" "mainAssociation" {
  subnet_id      = aws_subnet.mainSubnet.id
  route_table_id = aws_route_table.mainRoute.id
}

# 6. Create Security Group to allow port 22,80,443

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

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

# 7. Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.mainSubnet.id
  private_ips     = ["10.0.1.20"]
  security_groups = [aws_security_group.allow_tls.id]
}

# 8. Assign an elastic IP to the network interface created in step 7

resource "aws_eip" "bar" {
  vpc                       = true
  network_interface         = aws_network_interface.test.id
  associate_with_private_ip = "10.0.1.20"
  depends_on                = [aws_internet_gateway.IGateway]
}

# 9. Create Ubuntu server and install/enable apache2

resource "aws_instance" "web-server-instance" {
  ami               = "ami-0d527b8c289b4af7f"
  instance_type     = "t2.micro"
  key_name          = "terraformLearning"
  

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.test.id
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF
  tags = {
    Name = "web-server"
  }
}


