data "aws_acm_certificate" "ssl" {
  domain      = "cobbtech.site"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

data "aws_route53_zone" "r53" {
    
  name         = "cobbtech.site."
}