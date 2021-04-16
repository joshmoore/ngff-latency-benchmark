
provider "aws" {
    region = "eu-west-1"
}

terraform {
    backend "s3" {}
}

variable "ssh_client_ip" {
    type    = string
}

variable "ssh_public_key" {
    type    = string
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "ngff-benchmarking-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "ngff-benchmarking-ig"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "ngff-benchmarking-rt"
  }
}

resource "aws_subnet" "subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true 
  availability_zone = "eu-west-1a"

  tags = {
    Name = "ngff-benchmarking-subnet"
  }
}

resource "aws_route_table_association" "rt_association" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_security_group" "security_group" {
  name        = "benchmarking_security_group"
  vpc_id      = aws_vpc.vpc.id

  egress {
    description = "Unsecured from internet"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Unsecured from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "TLS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Unsecured from internet"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Unsecured from VPC"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_client_ip]
  }

  tags = {
    Name = "benchmarking_security_group"
  }
}

data "aws_ami" "latest-ubuntu" {
  most_recent = true
  owners = ["099720109477"] # Canonical

  filter {
      name   = "name"
      values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
      name   = "virtualization-type"
      values = ["hvm"]
  }
}

resource "aws_key_pair" "ngffkey" {
  key_name   = "ngff-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "nginx_instance" {
    ami = data.aws_ami.latest-ubuntu.id
    instance_type = "t3.medium"
    subnet_id = aws_subnet.subnet.id
    vpc_security_group_ids = [aws_security_group.security_group.id]
    root_block_device {
        volume_size = 256
    }
    key_name = aws_key_pair.ngffkey.key_name
  tags = {
    Name = "ngff-benchmarking-server"
  }
}

resource "aws_instance" "client_instance" {
    ami = data.aws_ami.latest-ubuntu.id
    instance_type = "t3.medium"
    subnet_id = aws_subnet.subnet.id
    vpc_security_group_ids = [aws_security_group.security_group.id]
    root_block_device {
        volume_size = 256
    }
    key_name = aws_key_pair.ngffkey.key_name
  tags = {
    Name = "ngff-benchmarking-client"
  }
}

output "instance_dns_1" {
  value = aws_instance.nginx_instance.public_dns
}

output "instance_dns_2" {
  value = aws_instance.client_instance.public_dns
}

resource "local_file" "hosts_cfg" {
  content = templatefile("${path.module}/hosts.tpl",
    {
      servers = aws_instance.nginx_instance.*.public_ip
      clients = aws_instance.client_instance.*.public_ip
    }
  )
  filename = "hosts.cfg"
}
