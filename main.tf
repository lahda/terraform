terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.16"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}
#création de vpc
resource "aws_vpc" "myVPC" {
  cidr_block = "10.0.0.0/16"

tags = {
    Name = "myVPC"
  }
} 

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.myVPC.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Public Subnet"
  }
}
#création du sous réseau privé
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.myVPC.id
  cidr_block = "10.0.2.0/24"


  tags = {
    Name = "Private Subnet"
  }
}
#création de la passerelle internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myVPC.id
  
  tags = {
    Name = "igw"
  }
}
#création de la table de routage
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.myVPC.id

   route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

   tags = {
    Name = "route-table"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}
#création de notre serveur Jenkins
resource "aws_instance" "jenkins_server"{
  ami           = "ami-0baa3f62c0ca83387"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id

  vpc_security_group_ids = [
      aws_security_group.ssh_access.id
  ]
  #script d'installation de jenkins
  user_data = <<-EOF
        #!/bin/bash
        wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
        sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
        sudo apt update && sudo apt upgrade -y
        sudo apt install default-jre -y
        sudo apt install jenkins -y
        sudo systemctl start jenkins
  EOF
    tags ={
    Name = "jenkins-instance",  
    }
}
#création du groupe de sécurité
  resource "aws_security_group" "ssh_access" {
  name_prefix = "ssh_access"
  vpc_id      =  aws_vpc.myVPC.id

#permission de connection ssh à notre serveur
  ingress {
    description = "Allow SSH from my computer"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #permission de tous les traffics à traversle port 8080
  ingress {
    description = "Allow all traffic through port 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #permission à notre serveur de toucher internet
  egress {
    description = "Allow all outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#création d'une adresse ip élastique
resource "aws_eip" "eip" {
  instance = aws_instance.jenkins_server.id

  tags = {
    Name = "test-eip"
  }
}

