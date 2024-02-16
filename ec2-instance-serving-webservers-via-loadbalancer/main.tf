terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = "AKIA6LOB7QER4GUKOJPV"
  secret_key = "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"
}


resource "aws_vpc" "test-vpc" {
    cidr_block = var.cidr
}

resource "aws_subnet" "test-subnet-1" {
    vpc_id = aws_vpc.test-vpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone =  "us-east-1a"
    map_public_ip_on_launch =  true
}

resource "aws_subnet" "test-subnet-2" {
    vpc_id = aws_vpc.test-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone =  "us-east-1b"
    map_public_ip_on_launch =  true
}


resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.test-vpc.id

}

resource "aws_route_table" "RT" {
    vpc_id = aws_vpc.test-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.test-subnet-1.id
    route_table_id = aws_route_table.RT.id
}



resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.test-subnet-2.id
    route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "webSg" {
  name   = "web"
  vpc_id = aws_vpc.test-vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-sg"
  }
}


resource "aws_s3_bucket" "example" {
  bucket = "tf-deployed-s3-bucket"
}



resource "aws_instance" "webserver1" {
  ami                    = "ami-0261755bbcb8c4a84"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.test-subnet-1.id
  user_data              = base64encode(file("userdata.sh"))
}

resource "aws_instance" "webserver2" {
  ami                    = "ami-0261755bbcb8c4a84"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.webSg.id]
  subnet_id              = aws_subnet.test-subnet-2.id
  user_data              = base64encode(file("userdata1.sh"))
}

resource "aws_lb" "test-lb" {
    name = "test-tf-lb"
    internal = false
    load_balancer_type = "application"

    security_groups = [aws_security_group.webSg.id]
    subnets        = [aws_subnet.test-subnet-1.id, aws_subnet.test-subnet-2.id]

    tags =  {
        name = "web-lb"
    }
}

resource "aws_lb_target_group" "test-g" {
    name  =  "test-tf-lb-g"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.test-vpc.id

    health_check {
        path = "/"
        port = "traffic-port"
 
  }
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.test-g.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.test-g.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.test-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.test-g.arn
    type             = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.test-lb.dns_name
}





