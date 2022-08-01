variable "project" { }
variable "env" { }
variable "vpc_cidr" { }
variable "region" { }

variable "zone" {
    type = list
    default = ["a", "b", "c"]
}