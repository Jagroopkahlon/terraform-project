terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "jagroop-singh-1993"
    key    = "terraformstate_file"
    region = "us-east-2"
  }
}


# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
}


#create key pair
resource "aws_key_pair" "terraform-demo-key" {
  key_name   = "terraform-demo-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJAZcBCfYL0JKBf2ZVg3JMGfOvgjuFbLuTknHGFP+NrC 13065@Jagroop-laptop"
}

#creating vpc
resource "aws_vpc" "amanpreet" {
  cidr_block       = "10.10.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "amanpreet"
  }
}

#creating public subnet from amanpreet vpc
resource "aws_subnet" "us-east-2a" {
  vpc_id     = aws_vpc.amanpreet.id
  cidr_block = "10.10.0.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "us-east-2a"

  tags = {
    Name = "public-subnet-2a"
  }
}

resource "aws_subnet" "us-east-2b" {
  vpc_id     = aws_vpc.amanpreet.id
  cidr_block = "10.10.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone = "us-east-2b"

  tags = {
    Name = "public-subnet-2b"
  }
}

#creating private subnet from amanpreet vpc
resource "aws_subnet" "us-east-2a-private" {
  vpc_id     = aws_vpc.amanpreet.id
  cidr_block = "10.10.2.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "private-subnet-2a-az"
  }
}

resource "aws_subnet" "us-east-2b-private" {
  vpc_id     = aws_vpc.amanpreet.id
  cidr_block = "10.10.3.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "private-subnet-2b-az"
  }
}
#create security group
resource "aws_security_group" "allow_port_22" {
  name        = "allow_port_22"
  description = "Allow ssh inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.amanpreet.id

  tags = {
    Name = "allowport22"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_port_22" {
  security_group_id = aws_security_group.allow_port_22.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_port_80" {
  security_group_id = aws_security_group.allow_port_22.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.allow_port_22.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# attach internet gateway to VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.amanpreet.id

  tags = {
    Name = "terraform IG"
  }
}

# attach route table to public IG
resource "aws_route_table" "public_RT" {
  vpc_id = aws_vpc.amanpreet.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "PUBLIC ROUTETABLE"
  }
}

resource "aws_route_table_association" "RT_asscociation" {
  subnet_id      = aws_subnet.us-east-2a.id
  route_table_id = aws_route_table.public_RT.id
}

resource "aws_route_table_association" "RT_asscociation2" {
  subnet_id      = aws_subnet.us-east-2b.id
  route_table_id = aws_route_table.public_RT.id
}

#attach RT to private subnet
resource "aws_route_table" "private_RT" {
  vpc_id = aws_vpc.amanpreet.id

  tags = {
    Name = "private ROUTETABLE"
  }
}
resource "aws_route_table_association" "RT_asscociation3" {
  subnet_id      = aws_subnet.us-east-2a-private.id
  route_table_id = aws_route_table.private_RT.id
}

resource "aws_route_table_association" "RT_asscociation4" {
  subnet_id      = aws_subnet.us-east-2b-private.id
  route_table_id = aws_route_table.private_RT.id
}



#create target group
resource "aws_lb_target_group" "targetgroup1" {
  name     = "target1a"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.amanpreet.id
}

#create listener
resource "aws_lb_listener" "project_listener" {
  load_balancer_arn = aws_lb.terraformLB.arn
  port              = "80"
  protocol          = "HTTP"
 
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targetgroup1.arn
  }
}

#create loadbalancer
resource "aws_lb" "terraformLB" {
  name               = "terraformLB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_port_22.id]
  subnets            = [aws_subnet.us-east-2a.id,aws_subnet.us-east-2b.id]

  tags = {
    Environment = "production"
  }
}

#launch template for ASG
resource "aws_launch_template" "projectLT" {
name = "projectLT"
image_id = "ami-0b4750268a88e78e0"
 instance_type = "t2.micro"
 key_name = aws_key_pair.terraform-demo-key.id
vpc_security_group_ids = [aws_security_group.allow_port_22.id]
 tag_specifications {
    resource_type = "instance"
tags = {
      Name = "projectLT"
    }
  }
 user_data = filebase64("userdata.sh")
}
 
#create ASG
resource "aws_autoscaling_group" "ASGNEW" {
  vpc_zone_identifier = [ aws_subnet.us-east-2a.id, aws_subnet.us-east-2b.id ]
  desired_capacity   = 2
  max_size           = 2
  min_size           = 2
  target_group_arns = [ aws_lb_target_group.targetgroup1.arn ]

  launch_template {
    id      = aws_launch_template.projectLT.id
    version = "$Latest"
  }
}

