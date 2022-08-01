output "cidr" {
    value = module.vpc.vpc_id
}

output "pub_subnet" {
    value = module.vpc.public_subnet
}

output "priv_subnet" {
    value = module.vpc.private_subnet
}