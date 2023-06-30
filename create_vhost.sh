#!/bin/bash

# Functions
ok() {
  echo -e '\e[32m'$1'\e[m' # Green
}

die() {
  echo -e '\e[1;31m'$1'\e[m'
  exit 1
}

get_fastcgi_pass() {
  running_fpm=$(ss -l | grep -o -P '.{0,4}fpm.sock')
  if [ -z "$running_fpm" ]; then
    echo "127.0.0.1:9000"
  elif [ "$running_fpm" == 'php-fpm.sock' ]; then
    echo "unix:/run/php/$running_fpm"
  else
    echo "unix:/run/php/php$running_fpm"
  fi
}

# Script parameters
action="$1"

# Variables
php_version=$(php -v | awk '/^PHP/ {print $2}')
ip='127.0.0.1'
default_root='/var/www/'
sample_vhost_file='sample_vhost.conf'
owner=$(who am i | awk '{print $1}')
sitesEnable='/etc/nginx/sites-enabled/'
sitesAvailable='/etc/nginx/sites-available/'
hostsFile='/etc/hosts'
fastcgi_pass=$(get_fastcgi_pass)

# Validate action
if [[ ! $action =~ ^(create|delete)$ ]]; then
  die "Invalid action. Valid actions are 'create' or 'delete'"
fi

read -p "Your Domain (e.g., example.com): " domain

if [ "$action" == 'create' ]; then
  read -p "Your Server rootpath (press enter to use default - $default_root): " serverroot
  serverroot="${serverroot:-$default_root}"
  root="$serverroot$domain"
  webroot="$root/html"
  logpath="$root/logs"

  # Create Directories
  mkdir -p "$webroot" "$logpath"
  chmod 755 "$root" || die "Failed to set permissions for $root"

  if [ ! -d "$webroot" ] || [ ! -d "$logpath" ]; then
    die "Directory creation failed"
  fi

  # Create site config
  sudo cp "$sample_vhost_file" "$sitesAvailable$domain"
  # Set domain
  sudo sed -i "s/@domain/$domain/g" "$sitesAvailable$domain"

  # Set log path
  sudo sed -i "s|@logpath|$logpath|g" "$sitesAvailable$domain"

  # Set webroot
  sudo sed -i "s|@webroot|$webroot|g" "$sitesAvailable$domain"

  # Set fpm version
  sudo sed -i "s|#fastcgi_pass|$fastcgi_pass|g" "$sitesAvailable$domain"

  # Create symbolic link for site config
  sudo ln -nsf "$sitesAvailable$domain" "$sitesEnable$domain"

  # Add Domain in hosts file
  echo -e "\n$ip\t$domain" | sudo tee -a "$hostsFile" > /dev/null

  if ! echo "
    <?php
    echo '<h1>Hi, Your site is ready</h1>';
    echo '<h4>Domain : $domain</h4>';
    echo '<h4>Site root : $webroot</h4>';
    echo '<h4>Site Logs : $logpath</h4>';
    ?>
    " > "$webroot/index.php"; then
    die "There was an error creating $webroot/index.php"
  else
    echo -e "\nNew Virtual Host Created\n"
  fi

  # Restart Nginx
  sudo service nginx reload || die "Failed to restart Nginx"

  echo "Your site is ready: http://$domain"
fi

# Delete site
if [ "$action" == 'delete' ]; then
  if [ ! -e "$sitesAvailable$domain" ]; then
    die "$sitesAvailable$domain: File does not exist"
  fi

  root=$(grep -m 1 -o -P "(?<=root).*(?=$domain)" "$sitesAvailable$domain")
  rootfullpath="$root$domain"

  # Remove virtual host configuration
  sudo rm -rf "$sitesAvailable$domain" "$sitesEnable$domain"
  echo "Deleted: $sitesAvailable$domain"
  echo "Deleted: $sitesEnable$domain"

  if [ -e "$rootfullpath" ]; then
    sudo rm -rf "$rootfullpath"
    echo "Deleted: $rootfullpath"
  fi

  # Remove domain from hosts file
  sudo sed -i "/$domain/d" "$hostsFile"
  echo "Hosts entry removed: $domain"

  ok "$domain is removed from your system"
fi
