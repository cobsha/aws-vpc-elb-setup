module "vpc" {
    source = "../module"
    vpc_cidr = var.cidr
    project = var.project
    env = var.env
    region = var.region
}

resource "aws_security_group" "bastion" {

  name_prefix = "bastion-"
  description = "Allow Public SSH Access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "SSH Access"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {

    create_before_destroy = true
  }

  tags = {
    Name = "${var.project}-${var.env}-bastion-SG"
    project = var.project
    env = var.env
  }
}

resource "aws_security_group" "webserver" {
  name_prefix = "webserver-"
  description = "SG for ELB and webserver"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "SSH Access"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    description      = "HTTP Access"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTPS Access"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.project}-${var.env}-webserver-SG"
    project = var.project
    env = var.env
  }
}

resource "aws_key_pair" "key" {
  key_name   = "${var.project}-${var.env}-key"
  public_key = file("key.pub")
}

resource "aws_instance" "bastion" {

  ami           = var.instance_ami
  instance_type = var.instance_type
  key_name = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  subnet_id = module.vpc.public_subnet[0]

  tags = {
    Name = "${var.project}-${var.env}-bastion"
    project = var.project
    env = var.env
  }
}

resource "aws_instance" "webserver" {

  count = 2
  ami           = var.instance_ami
  instance_type = var.instance_type
  key_name = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.webserver.id]
  subnet_id = module.vpc.private_subnet[count.index]
  user_data = file("user_data.sh")

  tags = {
    Name = "${var.project}-${var.env}-webserver-${count.index +1}"
    project = var.project
    env = var.env
  }
}

resource "aws_elb" "elb" {
  name_prefix = "elb-"
  subnets = module.vpc.public_subnet
  security_groups = [aws_security_group.webserver.id]
  instances = aws_instance.webserver[*].id

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port      = 80
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = data.aws_acm_certificate.ssl.arn
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 120
  connection_draining         = true
  connection_draining_timeout = 120

  lifecycle {

    create_before_destroy = true
  }

  tags = {
    Name = "${var.project}-${var.env}-elb"
    project = var.project
    env = var.env
  }
}

resource "aws_route53_record" "record" {

  zone_id = data.aws_route53_zone.r53.zone_id
  name    = "zomato.${data.aws_route53_zone.r53.name}"
  type    = "A"
  alias {
    name                   = "${aws_elb.elb.dns_name}"
    zone_id                = "${aws_elb.elb.zone_id}"
    evaluate_target_health = true
  }
}