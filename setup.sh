#!/bin/bash
sudo apt update
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
echo "<h1>Welcome to the Three-Tier Azure Architecture!</h1>" | sudo tee /var/www/html/index.html