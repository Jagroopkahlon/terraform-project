#!/bin/bash
sudo apt-get update && sudo apt-get install apache2 -y
sudo systemctl status apache2
git clone https://github.com/amolshete/card-website.git
sudo cp -rf card-website/* /var/www/html/