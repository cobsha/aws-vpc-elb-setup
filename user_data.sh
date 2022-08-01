#!/bin/bash

yum install httpd php git -y
systemctl enable httpd --now

git clone https://github.com/cobsha/aws-elb-site.git /var/website/
cp -r /var/website/* /var/www/html/
chown -R apache:apache /var/www/html
