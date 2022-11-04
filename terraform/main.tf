provider "aws" {
    region = "us-east-1"
  
}



resource "aws_vpc" "first-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "RK_Test_VPC"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.first-vpc.id

  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "rk-route-table" {
  vpc_id = aws_vpc.first-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "rk-route-table"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.first-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "RK_Test_Subnet"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.rk-route-table.id
}

resource "aws_security_group" "rk-security-group" {
  name        = "allow_web"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.first-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }
ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
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
    Name = "allow_web_traffic"
  }
}

resource "aws_network_interface" "rk-webserver" {
  subnet_id       = aws_subnet.main.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.rk-security-group.id]
  
}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.rk-webserver.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.gw
  ]
}

resource "aws_instance" "my-first-server" {
ami           = "ami-08c40ec9ead489470"
instance_type = "t2.micro"
availability_zone = "us-east-1a"
key_name = "rktest-access-key"
network_interface {
  device_index=0
  network_interface_id = aws_network_interface.rk-webserver.id
}
tags = {
  Name = "RKTest Server"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo very first webserver > /var/www/html/index.html'
              EOF
}
