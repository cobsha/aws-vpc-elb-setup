
# AWS VPC-ELB Setup using Terraform

Terraform is an open source Infrastructure as Code tool used to provision Infrastructure and resources.
We can automate major cloud platforms like AWS, Azure or GCP using terraform.

I wrote a terraform code to create an entire VPC  as a module, this can be included in any infra creation for setting up VPC, all you need to just call it with proper variables. along with VPC i have also setup elastic load balancer with 2 instances, These instances placed in a private subnet and a static website deployed in it,
the website can be accessed from anywhere in internet via ELB. There is a reason why we deploy application and Database servers in a private subnet,
it will increase the security of the server by not exposing it directly to the public. Inorder to access this webserver we need an another instance deployed in a public subnet called bastion host.

![VPC-ELB](https://user-images.githubusercontent.com/71638921/182177823-08fae2b0-3cbb-4511-a537-7738ebdfa435.jpg)


## Prerequsites

* An AWS Account with an IAM user which has programmatic access and VPC and Instance level access
* Teraform Installed machine, you can refer official doc. https://www.terraform.io/downloads
* A domain name hosted in route53
* A TLS Certificate from ACM


## Setup
We are starting this from VPC module Setup, then ELB setup and Instances.

### Module Setup
Entire VPC including Internetgateway, Natgateway and associated Elastic Ip, Routetable creation and Association set it up in a seperate module in a seperate directory and it's completely isolated from the main code, so that we can use this in any infra setup. so, we create 2 directories named module and project_dir (name doesn't matter). 
In module setup we don't do hardcording data instead we use variables to represent data. We have main.tf, variables.tf and output.tf in module directory(It doesn't matter what file name is, the extension should be .tf and we can combine everything in a single file if we want)

![Screenshot from 2022-08-01 12-32-21](https://user-images.githubusercontent.com/71638921/182099972-52fc6b95-e28b-45c6-8eae-797d7df8f1fc.png)


### VPC Creation
variables declaration in module
```bash
#variables.tf
variable "project" { }
variable "env" { }
variable "vpc_cidr" { }
variable "region" { }

variable "zone" {
    type = list
    default = ["a", "b", "c"]
}
```
necessary output we need to use in project_dir
```bash
#ouput.tf
output "vpc_id" {
    value = aws_vpc.main.id
}

output "public_subnet" {
    value = aws_subnet.public[*].id
}

output "private_subnet" {
    value = aws_subnet.private[*].id
}
```

```bash
#main.tf
#---------
  resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-${var.env}-vpc"
    project = var.project
    env = var.env
  }
  }
```

### Internet Gateway

```bash
#main.tf
  resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-${var.env}-igw"
    project = var.project
    env = var.env
  }
  }
```

### Public and Private Subnet

Public Subnet
```bash
  resource "aws_subnet" "public" {

  count = 3
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.vpc_cidr, 3, count.index)
  availability_zone = "${var.region}${var.zone[count.index]}"
  enable_resource_name_dns_a_record_on_launch = true
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-public-${count.index +1}"
    project = var.project
    env = var.env
  }
  lifecycle {

    create_before_destroy = true
  }
  }
```

```bash
  resource "aws_subnet" "private" {

  count = 3
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.vpc_cidr, 3, count.index+3)
  availability_zone = "${var.region}${var.zone[count.index]}"

  tags = {
    Name = "${var.project}-private-${count.index +4}"
    project = var.project
    env = var.env
  }
  lifecycle {

    create_before_destroy = true
  }
  }
```

### Elastic IP and Natgateway

Natgateway provides internet access to the instances in the private subnets

```bash
  resource "aws_eip" "eip" {
  vpc      = true
  tags = {
    Name = "${var.project}-${var.env}-eip"
    project = var.project
    env = var.env
  }
  }

resource "aws_nat_gateway" "ngw" {

  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project}-${var.env}-igw"
    project = var.project
    env = var.env
  }
  depends_on = [aws_internet_gateway.igw]
  }
```

### RouteTables and Its Association

```bash
  esource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}-${var.env}-public"
    project = var.project
    env = var.env
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "${var.project}-${var.env}-private"
    project = var.project
    env = var.env
  }
}
```

```bash
  resource "aws_route_table_association" "public" {

  count = 3 
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {

  count = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

### Project Directory Setup

![Screenshot from 2022-08-01 13-24-31](https://user-images.githubusercontent.com/71638921/182100585-61cdc11b-58e6-4ce8-9f59-3dcb9bef76b6.png)

We need to create 5 terraform files named provider.tf, main.tf, variables.tf, output.tf and datasource.tf, we communicate with aws using the credential in the file named provider.tf (If you are using ec2 istance to manage terraform it is best practice to use role instead of security key pair), 

```bash
 #provider.tf
 provider "aws" {

  region = var.region
  access_key = "Enter Your Access key"
  secret_key = "Enter your secret key"   
}
```
We need to initialize provider after configuring it in the file provider.tf. use below commands to initialize.
![Screenshot from 2022-08-01 13-36-23](https://user-images.githubusercontent.com/71638921/182102656-8bede63a-1557-44da-b4b3-74e6ff23d44f.png)


Variables declaration
```bash
#variables.tf
variable "region" {

    default = "ap-south-1"
}

variable "project" {

    default = "zomato"
}

variable "env" {

    default = "prod"
}

variable "cidr" {

    default = "172.16.0.0/16"
}

variable "instance_type" {

    default = "t2.micro"
}

variable "instance_ami" {

    default = "ami-08df646e18b182346"
}

variable "zone" {

    type = list
    default = ["a", "b", "c"]
}
```

```bash
#output.tf
output "cidr" {
    value = module.vpc.vpc_id
}

output "pub_subnet" {
    value = module.vpc.public_subnet
}

output "priv_subnet" {
    value = module.vpc.private_subnet
}
```

```bash
#datasource.tf
data "aws_acm_certificate" "ssl" {
  domain      = "cobbtech.site"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

data "aws_route53_zone" "r53" {
    
  name         = "cobbtech.site."
}
```

Calling module for creating VPC

```bash
#main.tf
module "vpc" {
    source = "../module" #you need to specify your module path
    vpc_cidr = var.cidr
    project = var.project
    env = var.env
    region = var.region
}
```
Creating Security Group for Bastion and webserver
```bash
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

```
Key pair creation for accessing the instances

```bash
 resource "aws_key_pair" "key" {
  key_name   = "${var.project}-${var.env}-key"
  public_key = file("key.pub")
}
```
bastion and webserver instance creation
```bash
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
```




### Elastic Load Balancer Creation

Inorder to acces our webserver we need a loadbalancer
```bash
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
    ssl_certificate_id = data.aws_acm_certificate.ssl.arn ##I have already created a tls certificate from ACM service in AWS, and we can access those certificate via datasource
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
```
### Adding Record to the Route53

We can access our domain using datasource and add a record
```bash
  zone_id = data.aws_route53_zone.r53.zone_id
  name    = "zomato.${data.aws_route53_zone.r53.name}"
  type    = "A"
  alias {
    name                   = "${aws_elb.elb.dns_name}"
    zone_id                = "${aws_elb.elb.zone_id}"
    evaluate_target_health = true
  }
}
```
Inorder to validate and apply all these code, we need to enter following command.
```bash
terraform validate
terraform apply
```
![Screenshot from 2022-08-01 21-43-11](https://user-images.githubusercontent.com/71638921/182194686-80fa7aad-18c9-4db3-8157-630e254c0c12.png)
![Screenshot from 2022-08-01 21-59-07](https://user-images.githubusercontent.com/71638921/182198180-c69a36b8-3b77-433d-9995-cb09c0fe896c.png)

