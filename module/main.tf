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

resource "aws_internet_gateway" "igw" {

  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-${var.env}-igw"
    project = var.project
    env = var.env
  }
}

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

resource "aws_route_table" "public" {
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