#!/bin/bash

#Functions
ok() { echo -e '\e[32m'$1'\e[m'; } # Green

die() { echo -e '\e[1;31m'$1'\e[m'; exit 1; }

get_fastcgi_pass() {
    running_fpm=$(ss -l | grep -o -P '.{0,4}fpm.sock');
    if [ "$running_fpm" == '' ]
    then
        echo "127.0.0.1:9000";
    fi
    if [ "$running_fpm" == 'php-fpm.sock' ]
    then
        echo "unix:/run/php/$running_fpm";
    fi
    echo "unix:/run/php/php$running_fpm";
}

# script parameters
action="$1"

# Variables
php_version=$(php -v | grep ^PHP | cut -d' ' -f2)
ip='127.0.0.1'
default_root='/var/www/'
sample_vhost_file='sample_vhost.conf'
owner=$(who am i | awk '{print $1}')
sitesEnable='/etc/nginx/sites-enabled/'
sitesAvailable='/etc/nginx/sites-available/'
hostsFile='/etc/hosts'
fastcgi_pass=$( get_fastcgi_pass );
if [ $action != 'create' ] && [ "$action" != 'delete' ] 
then
	die "Invalid action. Valid actions (create/delete)";
fi

read -p "Your Domain (eg. example.com): " domain

if [ "$action" == 'create' ]
then
    read -p "Your Server rootpath (press enter to use default - $default_root)" serverroot
    if [ "$serverroot" == '' ]
        then
        serverroot=$default_root;
    fi
    root="$serverroot$domain"
    webroot="$root"/html
    logpath="$root"/logs

    # Create Directories
    mkdir -p "$webroot"
    mkdir -p "$logpath"
	chmod 755 "$root"

    if [ ! -e "$webroot" ]; then
		echo "Root directory creation failed."
        exit 0;
    fi
    if [ ! -e "$logpath" ]; then
		echo "Logs directory creation failed."
        exit 0;
    fi

    #Create site config
    sudo cp "$sample_vhost_file" "$sitesAvailable$domain";
    # Setdomain
    sudo sed -i "s/@domain/$domain/g" "$sitesAvailable$domain";
    
    # set log path
    sudo sed -i "s,@logpath,$logpath,g" "$sitesAvailable$domain";

    # set Webroot
    sudo sed -i "s,@webroot,$webroot,g" "$sitesAvailable$domain";

    # set fpm version
    sudo sed -i "s,#fastcgi_pass,$fastcgi_pass,g" "$sitesAvailable$domain";

    #Create short link, for site config.
    sudo ln -nsf "$sitesAvailable$domain" "$sitesEnable$domain";

    # Add Domain in hosts file
    sudo echo -e "\n$ip	$domain" >> "$hostsFile"

    if ! echo "
    <?php
        echo '<h1>Hi, Your site is ready</h1>'; 
        echo '<h4>Domain : $domain</h4>'; 
        echo '<h4>Site root : $webroot</h4>'; 
        echo '<h4>Site Logs : $logpath</h4>'; 
    ?>
    " > $webroot/index.php
    then
        die "There is an ERROR in creating $webroot/index.php file"
    else
        echo -e $"\nNew Virtual Host Created\n"
    fi

    ### restart Nginx
	sudo service nginx reload
    
    echo "Your site is ready : http://$domain"
fi

# delete site 
if [ "$action" == 'delete' ]
then

    if [ ! -e "$sitesAvailable$domain" ]; then
		die "$sitesAvailable$domain : File Not Exist"
    fi

    root=$(grep -m 1 -o -P "(?<=root).*(?=$domain)" $sitesAvailable$domain);
    rootfullpath="$root$domain"
    
    # Remove virtual host configuration
    sudo rm -rf "$sitesAvailable$domain"
    sudo rm -rf "$sitesEnable$domain"
    echo "Deleted : $sitesAvailable$domain "
    echo "Deleted : $sitesEnable$domain "

    if [ -e "$rootfullpath" ]; then
        sudo rm -rf "$rootfullpath"
        echo "Deleted : $rootfullpath "
    fi
   
    # Fetch host file data and delete line which contains given domain
    hosts_filedata=$(sudo grep -v "$domain" "$hostsFile")
    
    # Remove domain from hosts file content and again add to hosts file
    sudo sed -i "/$domain/d" $hostsFile
    echo "hosts entry removed : $domain"

    ok "$domain is removed from your system"
fi