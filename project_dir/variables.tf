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