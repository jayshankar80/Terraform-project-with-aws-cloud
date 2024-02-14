provider "aws" {
  region     = "us-east-1"
  access_key = "AKIA6LOB7QER4GUKOJPV"
  secret_key = "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"
}

resource "aws_vpc" "test-vpc" {
  cidr_block = "10.0.0.0/16"

   tags = {
    Name = "main"
  }
}
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.test-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "public"
  }

  depends_on = [
    aws_vpc.test-vpc
  ]

}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.test-vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "private"
  }

   depends_on = [
    aws_vpc.test-vpc
  ]

}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.test-vpc.id

  tags = {
    Name = "Internet Gateway"
  }

 depends_on = [
    aws_vpc.test-vpc
  ]
  
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.test-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "public_1_rt_a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id

  depends_on = [
    aws_subnet.public_subnet
  ]

}

resource "aws_security_group" "EC2_Security_Group" {
  name   = "HTTP and SSH"
  vpc_id = aws_vpc.test-vpc.id
  

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "EC2" {
  ami           = "ami-0e731c8a588258d0d"
  instance_type = "t2.micro"
  key_name      = "my-key"

  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.EC2_Security_Group.id]
  associate_public_ip_address = true

   user_data = <<-EOF
  #!/bin/bash -ex

  sudo yum install nginx -y
  sudo echo "<h1>$(curl https://api.kanye.rest/?format=text)</h1>" >  /usr/share/nginx/html/index.html 
  sudo systemctl enable nginx
  sudo systemctl start nginx
  EOF

  tags = {
    "Name" : "my_first_ec2_instance_with_terraform"
  }
}
