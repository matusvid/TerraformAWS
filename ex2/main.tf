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


// Subnet 1 - Private
resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.mainVPC.id
  cidr_block = "10.0.0.0/26"
  availability_zone = var.avaiZones[1]

  tags = {
    Name = "subnet1"
  }
}

// Subnet 2 - Private
resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.mainVPC.id
  cidr_block = "10.0.1.0/26"
  availability_zone = var.avaiZones[0]

  tags = {
    Name = "subnet2"
  }
}

// Subnet 3 - Public
resource "aws_subnet" "subnet3" {
  vpc_id     = aws_vpc.mainVPC.id
  cidr_block = "10.0.2.0/26"
  availability_zone = var.avaiZones[1]

  tags = {
    Name = "subnet1"
  }
}

// Subnet 4 - Public
resource "aws_subnet" "subnet4" {
  vpc_id     = aws_vpc.mainVPC.id
  cidr_block = "10.0.3.0/26"
  availability_zone = var.avaiZones[0]

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

// NAT Public 1
resource "aws_nat_gateway" "natPub1" {
  allocation_id = aws_eip.one.id
  subnet_id     = aws_subnet.subnet1.id

  tags = {
    Name = "gw NATPub1"
  }

  depends_on = [aws_internet_gateway.gw]
}

// EIP 1
resource "aws_eip" "one" {
  vpc                       = true
}

// Route Table Public
resource "aws_route_table" "rt1" {
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
    Name = "rt1"
  }
}

// Route Table Private
resource "aws_route_table" "rt2" {
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
    Name = "rt2"
  }
}

// routing ass1
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt1.id
}

// routing ass2
resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt1.id
}

// routing ass3
resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.rt2.id
}

// routing ass4
resource "aws_route_table_association" "d" {
  subnet_id      = aws_subnet.subnet4.id
  route_table_id = aws_route_table.rt2.id
}

resource "aws_security_group" "sec1" {
  name        = "sec1"
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
    Name = "sec1"
  }
}

resource "aws_security_group" "sec2" {
  name        = "sec2"
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
    Name = "sec2"
  }
}

resource "aws_launch_template" "launchInstances" {
  name          = "launchInstances"
  instance_type = var.instance
  key_name      = var.keyname
  image_id      = var.ami

  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.sec1.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "test"
    }
  }

  user_data = filebase64("${path.module}/data.userdata")
}

resource "aws_lb" "lb1" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sec2.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "lb-tg1" {
  name     = "example"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.mainVPC.id
}

resource "aws_lb_listener" "lb-list" {
  load_balancer_arn = aws_lb.lb1.id
  port = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.lb-tg1.id
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "static" {
  listener_arn = aws_lb_listener.lb-list.id
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-tg1.id
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

resource "aws_autoscaling_group" "asg" {
  name                      = "foobar3-terraform-test"
  max_size                  = 2
  min_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.subnet3.id, aws_subnet.subnet4.id]
  

  target_group_arns = [aws_lb_target_group.lb-tg1.arn]

  launch_template {
    id      = aws_launch_template.launchInstances.id
    version = "$Latest"
  }

}



