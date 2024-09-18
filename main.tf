# Definir o VPC
resource "aws_vpc" "app_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "app-vpc"
  }
}

# Subnets em múltiplas zonas de disponibilidade
resource "aws_subnet" "public_subnets" {
  count             = 2
  vpc_id            = aws_vpc.app_vpc.id
  cidr_block        = cidrsubnet(aws_vpc.app_vpc.cidr_block, 8, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "public-subnet-${count.index}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "app-igw"
  }
}

# Rota para a Internet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_route_association" {
  count          = 2
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.public_route_table.id
}

# Security Group para o Load Balancer, EC2, e RDS
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.app_vpc.id # Garantindo que está no mesmo VPC

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "app-sg"
  }
}

# Elastic Load Balancer (ELB)
resource "aws_lb" "app_lb" {
  name               = "app-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets            = aws_subnet.public_subnets[*].id

  tags = {
    Name = "app-load-balancer"
  }
}

# Listeners do Load Balancer
resource "aws_lb_listener" "app_lb_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_lb_tg.arn
  }
}

# Target Group
resource "aws_lb_target_group" "app_lb_tg" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.app_vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "app-target-group"
  }
}

# Definição da AMI
data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  owners = ["137112412989"] # Amazon
}

# Auto Scaling Launch Configuration
resource "aws_launch_template" "app_launch_template" {
  name_prefix            = "app-launch-template-"
  image_id               = data.aws_ami.app_ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo yum install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              echo "<h1>Web App Running</h1>" | sudo tee /var/www/html/index.html
              EOF
  )

  tags = {
    Name = "app-launch-template"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  launch_template {
    id      = aws_launch_template.app_launch_template.id
    version = "$Latest"
  }

  vpc_zone_identifier       = aws_subnet.public_subnets[*].id
  min_size                  = 2
  max_size                  = 6
  desired_capacity          = 2
  health_check_type         = "EC2"
  health_check_grace_period = 300

  target_group_arns = [aws_lb_target_group.app_lb_tg.arn]

  tag {
    key                 = "Name"
    value               = "App EC2 Instance"
    propagate_at_launch = true
  }
}

# Subnet Group para o RDS
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "app-db-subnet-group"
  subnet_ids = aws_subnet.public_subnets[*].id

  tags = {
    Name = "app-db-subnet-group"
  }
}

# RDS (Banco de dados MySQL)
resource "aws_db_instance" "app_db" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.mysql5.7"
  publicly_accessible  = false
  skip_final_snapshot  = true

  # VPC Security Group deve ser o mesmo da aplicação
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # Garantir que está no VPC correto
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name

  tags = {
    Name = "app-rds-db"
  }
}
