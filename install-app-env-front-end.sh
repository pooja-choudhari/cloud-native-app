#!/bin/bash

sudo apt-get -y update
sudo apt-get -y install apache2 php php-gd php-curl php7.2-xml awscli zip unzip awscli

cd /home/ubuntu

# Getting Composer to install the AWS PHP SDK
sudo -u ubuntu php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
sudo -u ubuntu php -r "if (hash_file('sha384', 'composer-setup.php') === 'a5c698ffe4b8e849a443b120cd5ba38043260d5c4023dbf93e1558871f1f07f58274fc6f4c93bcfd858c6bd0775cd8d1') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo -u ubuntu php composer-setup.php
sudo -u ubuntu php -r "unlink('composer-setup.php');"

# Installing the actual AWS SDK
sudo php -d memory_limit=-1 /home/ubuntu/composer.phar require aws/aws-sdk-php

# Enable apache2 on the EC2
sudo systemctl enable apache2
sudo systemctl restart apache2

sudo mkdir uploads
sudo chown -R www-data:www-data uploads

cd /

# Cloning public repository: jhajek
git clone https://github.com/illinoistech-itm/jhajek.git
sudo cp jhajek/itmo-444/Week-07/index.php /var/www/html/test.php

# Cloning public repository: cpooja using AMI image with SSH keys pre-loaded. 
git clone git@github.com:illinoistech-itm/cpooja.git
sudo cp /cpooja/mp2/application/index.php /var/www/html/index.php
sudo cp /cpooja/mp2/application/gallery.php /var/www/html/gallery.php
sudo cp /cpooja/mp2/application/submit.php /var/www/html/submit.php
sudo cp -r /cpooja/mp2/application/css/ /var/www/html/css/
sudo cp /cpooja/mp2/dbinfo.inc /home/ubuntu/dbinfo.inc
