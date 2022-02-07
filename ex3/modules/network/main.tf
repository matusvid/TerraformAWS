// CORE VPC
resource "aws_vpc" "mainVPC" {
  cidr_block        = "10.0.0.0/20"
  instance_tenancy  = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "main"
  }
}


// Subnet 1 - Public
resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.mainVPC.id
  cidr_block = "10.0.0.0/26"
  availability_zone = var.avaiZones[1]

  tags = {
    Name = "subnet1"
  }
}

// Subnet 2 - Public
resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.mainVPC.id
  cidr_block = "10.0.1.0/26"
  availability_zone = var.avaiZones[0]

  tags = {
    Name = "subnet2"
  }
}

// Subnet 3 - Private
resource "aws_subnet" "subnet3" {
  vpc_id     = aws_vpc.mainVPC.id
  cidr_block = "10.0.2.0/26"
  availability_zone = var.avaiZones[1]

  tags = {
    Name = "subnet1"
  }
}

// Subnet 4 - Private
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