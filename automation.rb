apt_update 'Update the apt cache daily' do
  frequency 86_400
  action :periodic
end

package 'nginx drush'
package 'mysql-client mysql-server'

file '/tmp/install_php.sh' do
  content '/bin/bash -x
sudo apt-get install -q -y -f php7*'
end
execute 'php7 install' do
  command '/bin/bash /tmp/install_php.sh'
end
execute 'drush install drupal' do
  cwd '/usr/share/nginx/html'
  command 'drush dl drupal --destination=/usr/share/nginx/html/ --drupal-project-rename=drupal'
end
execute 'create user drupal' do
  command 'mysql -u root -e "Create USER if not exists drupal identified by \'drupal7\';"'
end
execute 'create drupal database' do
  command 'mysql -u root -e "Create DATABASE if not exists drupal7;"' 
end
execute 'grant user drupal' do
  command 'mysql -u root -e "GRANT ALL PRIVILEGES ON drupal7.*
  TO \'drupal\'@\'localhost\' IDENTIFIED BY \'drupal7\';"' 
end

execute 'drush mysql setup' do 
  cwd '/usr/share/nginx/html/drupal'
  command 'drush site-install standard -y --db-url=\'mysql://drupal:drupal7@localhost/drupal7\' --site-name=DrupalCivicExample --account-name=admin --account-pass=admin'
end

execute 'drush dl -y composer_generate' do 
  cwd '/usr/share/nginx/html/drupal'
  command 'drush dl composer_generate'
end
file '/etc/nginx/nginx.conf' do
content 'user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
	worker_connections 768;
	# multi_accept on;
}

http {

	##
	# Basic Settings
	##

	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;
	# server_tokens off;

	# set client body size to 2M #
	client_max_body_size 20M;

	# server_names_hash_bucket_size 64;
	# server_name_in_redirect off;

	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	##
	# SSL Settings
	##

	ssl_protocols TLSv1 TLSv1.1 TLSv1.2; # Dropping SSLv3, ref: POODLE
		ssl_prefer_server_ciphers on;
	ssl_ciphers "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS";


	##
	# Logging Settings
	##

	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log;

	##
	# Gzip Settings
	##

	#gzip on;
	#gzip_disable "msie6";

	# gzip_vary on;
	# gzip_proxied any;
	# gzip_comp_level 6;
	# gzip_buffers 16 8k;
	# gzip_http_version 1.1;
	# gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

	##
	# Virtual Host Configs
	##

	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
}


#mail {
#	# See sample authentication script at:
#	# http://wiki.nginx.org/ImapAuthenticateWithApachePhpScript
# 
#	# auth_http localhost/auth.php;
#	# pop3_capabilities "TOP" "USER";
#	# imap_capabilities "IMAP4rev1" "UIDPLUS";
# 
#	server {
#		listen     localhost:110;
#		protocol   pop3;
#		proxy      on;
#	}
# 
#	server {
#		listen     localhost:143;
#		protocol   imap;
#		proxy      on;
#	}
#}'
end
file '/etc/nginx/sites-available/drupal' do
  content '##
# You should look at the following URL\'s in order to grasp a solid understanding
# of Nginx configuration files in order to fully unleash the power of Nginx.
# http://wiki.nginx.org/Pitfalls
# http://wiki.nginx.org/QuickStart
# http://wiki.nginx.org/Configuration
#
# Generally, you will want to move this file somewhere, and start with a clean
# file but keep this around for reference. Or just disable in sites-enabled.
#
# Please see /usr/share/doc/nginx-doc/examples/ for more detailed examples.
##

# Default server configuration
#
server {
	listen 80;
	listen [::]:80;
	return 302 https://$server_name$request_uri;
}
server {
	# SSL configuration
	#
	listen 443 ssl http2;
	listen [::]:443 ssl http2;
#	server_name 34.200.52.199;
	include snippets/self-signed.conf;
	include snippets/ssl-params.conf;

	#
	# Note: You should disable gzip for SSL traffic.
	# See: https://bugs.debian.org/773332
	#
	# Read up on ssl_ciphers to ensure a secure configuration.
	# See: https://bugs.debian.org/765782
	#
	# Self signed certs generated by the ssl-cert package
	# Don\'t use them in a production server!
	#
	# include snippets/snakeoil.conf;
#removed below for drupal
#	root /var/www/html;
	root /usr/share/nginx/html/drupal;	

	# Add index.php to the list if you are using PHP
	index index.html index.htm index.nginx-debian.html index.php drupal;

	#server_name _;

	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
#old 		try_files $uri $uri/ =404;
		try_files $uri $uri/ /index.php?q=$uri&$args;
		proxy_set_header X-Forwarded-Proto https;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header Host $http_host;
		proxy_redirect off;
	}

	error_page 404 /404.html;
	error_page 500 502 503 504 /50x.html;
	location = /50x.html {


	}
	# pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
	#
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
	
		# With php7.0-cgi alone:
		#fastcgi_pass 127.0.0.1:9000;
		# With php7.0-fpm:
		fastcgi_pass unix:/run/php/php7.0-fpm.sock;
	}

	# deny access to .htaccess files, if Apache\'s document root
	# concurs with nginx\'s one
	#
	#location ~ /\.ht {
	#	deny all;
	#}
}


# Virtual Host configuration for example.com
#
# You can move that to a different file under sites-available/ and symlink that
# to sites-enabled/ to enable it.
#
#server {
#	listen 80;
#	listen [::]:80;
#
#	server_name example.com;
#
#	root /var/www/example.com;
#	index index.html;
#
#	location / {
#		try_files $uri $uri/ =404;
#	}
#}'
end
file '/tmp/link_drupal.sh' do 
 content '/bin/bash -x
sudo ln -s /etc/nginx/sites-available/drupal /etc/nginx/sites-enabled/drupal
'
end
execute 'link drupal site' do
  command '/bin/bash /tmp/link_drupal.sh'
end

file '/etc/ssl/certs/server.crt' do
  content '-----BEGIN CERTIFICATE-----
MIIDrDCCApQCCQCYSnuzvTjuFjANBgkqhkiG9w0BAQsFADCBlzELMAkGA1UEBhMC
Q0ExEDAOBgNVBAgMB09udGFyaW8xDzANBgNVBAcMBk90dGF3YTEhMB8GA1UECgwY
SW50ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkMRowGAYDVQQDDBFBaG1lZCBBYmRlbHJh
aG1hbjEmMCQGCSqGSIb3DQEJARYXYWhtYWQuYWJkZWxyYUBnbWFpbC5jb20wHhcN
MTcwMjE5MjEzNjUyWhcNMTgwMjE5MjEzNjUyWjCBlzELMAkGA1UEBhMCQ0ExEDAO
BgNVBAgMB09udGFyaW8xDzANBgNVBAcMBk90dGF3YTEhMB8GA1UECgwYSW50ZXJu
ZXQgV2lkZ2l0cyBQdHkgTHRkMRowGAYDVQQDDBFBaG1lZCBBYmRlbHJhaG1hbjEm
MCQGCSqGSIb3DQEJARYXYWhtYWQuYWJkZWxyYUBnbWFpbC5jb20wggEiMA0GCSqG
SIb3DQEBAQUAA4IBDwAwggEKAoIBAQCmVM+BfuOeN8S+aRGeO6CXPl4AJxIwu+VX
9sGbCoHjlA2CX2335lhWI8+XuUOVYU4qeiGH9y9xFyygoVKn5HFcy+/pFdJpdepY
rUuEeGc8uReI/OoqMGAsSXE11TCegN+h0Kihg8V+Ccaw9YgGoc08wBeca7rNZGrJ
3VbQA95CCr5/QuYG6N+TzKYO/NvPFy6h6IYtUXoJNlRBKmm7GNcKYXtID8V7jlSz
ey79WeU9buaWal0AT3wSpeYtjLOzGXkwADTgFiFAM5iObh0jpS08D5MvO9yUD4Mx
JGOSzDg9Ek8FMiMB/TVzwsN01ijUlFlc0O0Cw6sA4OgF+XTE+uRZAgMBAAEwDQYJ
KoZIhvcNAQELBQADggEBABHNaAJgxYPNWHjzBFMkhZN/Z2v4HJqSLHFcqyrO1nBb
ToZQcgMwU1kJK4vV7VbwAENbJnRbNACiQDwm9r7Q3gg4jOX2T9AUe8PkNqcyAhmk
Ug0rzC+jA3htIgLRApdCJ7LRZvUgccIJ6VPST+9v7AU4C1kIw4xUarjBvuYt+0zx
l/B5yQi+LqvXp2sHCh8zB0Rm4rlong/1RBo0pWyVjosR/xwQkJW1fJoMxYQdj74S
D1Ma000w8p2N1EALyu9+okEnRQxpItEnrdQPjuJ9BmDuO6jb/YFYDkDBDtbn9p0m
LbgraJxIOos/+cWxMcL655rm9O7eRMofVe3y5YrY9GA=
-----END CERTIFICATE-----
'
 mode '644'
 owner 'root'
end
file '/etc/ssl/private/server.key' do
  content '-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAplTPgX7jnjfEvmkRnjuglz5eACcSMLvlV/bBmwqB45QNgl9t
9+ZYViPPl7lDlWFOKnohh/cvcRcsoKFSp+RxXMvv6RXSaXXqWK1LhHhnPLkXiPzq
KjBgLElxNdUwnoDfodCooYPFfgnGsPWIBqHNPMAXnGu6zWRqyd1W0APeQgq+f0Lm
Bujfk8ymDvzbzxcuoeiGLVF6CTZUQSppuxjXCmF7SA/Fe45Us3su/VnlPW7mlmpd
AE98EqXmLYyzsxl5MAA04BYhQDOYjm4dI6UtPA+TLzvclA+DMSRjksw4PRJPBTIj
Af01c8LDdNYo1JRZXNDtAsOrAODoBfl0xPrkWQIDAQABAoIBAFvJ1bE6mtXHJNWH
GefeM+MC0dD3vrwSFKAUVgb/J2q1Wzck/oSdIwZ2QKsT283losMiHrrvl8iq5z/F
ht2L3Vs+V6ijGDiGj8pb55606xPBeNFp8LdTdt85sDXq7ieqKr8bbNOk6imBr5oc
BPLT+3SY9O6nLLEHxz6a3LtyRwbeDxBDJDgBo3VleNX1Wb+l2t9ZsjcEYSHUdxxE
qBJHHddkWc2+2he8pVoZGF5d97N16RaqBb96U2HoIdUY721eYsZShCITmrIRiuCh
L6Fh+1NdD0MAGOWUdjthHLChDug5FJ7d3fGDWJj3uanMN2aLdL7HKnZd5XT6BV16
wJ8R2mECgYEA1rXr8bOsFRir7HMXRjeHbli+0G2u9c9Z7V+kC3VdG5pLtkH8U264
kbsZpnE4vfI+v12FLImMHN0fnnopw3vBD6WR9H/KmBQqPIWWz+Pl/Hqi3fGs1ZTB
ga0scG/v1tXA40pIqUi0TCjjwHYBLzWX6LKbeNcBjJZKlP5B5PLTLuUCgYEAxlEz
0D7A3WbHGIVqDY0IFNnQhjf6klbJU2jzq+5HCSCmKXdwq40tNypH8tAt9w0HGBzb
TgqTRlHMpFXGfHsk78WY+VF5f3oRZNpkQrZUANMlet73b33xb1w/sld4R699f+PW
FsHItIqeGP+rBQMR0nWaK/INUl28hHEAWyiJlGUCgYEAhyOPstx0hf62TyeNUZun
uTNQPl2azopIvpgA51liVfpChx93EohQ0SCjH1iJ7zvmdIoHRSX5sz0WJqgbWzes
Jw3+FJbOS/P9NYSbjJOTcNs7YVg4gWGUfesiWk6J9X0qX6SkoS/qkzj1SHC9hBpG
V6b7Jg6lofgCT07M6K5Rb2UCgYB3oAvNFc1ov9Jg7Dkoq2WwjiLGk4XGOCuA8NHr
Z/PZgaQ5Zx7DnIkluY9k3Eadu3IIDYAL9z0XMchraIIuHGoPZ/X6jjbnuk47s7C+
vRS22qbFEzHWQvYb4l1ZyoF3XFgriNdfKs1SejsbgT077LoXZXD2CTAX+wr4KOG6
Gx3CMQKBgDbVlx0amPFcYZWfE9IpRV0W+lBIeR/FJHx1ux4eUdTiNyqLJKgMx+tX
8S6AeE9mPKaoAyYtfBoHA5LQomHUCYQHXDjARvryW4zTWAxSAV/NNusMFmBJM4Oa
j4O+D0kOfU0qHmmDUOdXsHH3+yG1Edw8yB0HFSOzO6iwXjjOZJa0
-----END RSA PRIVATE KEY-----
'
 mode '644'
 owner 'root'
end
file '/etc/ssl/certs/dhparam.pem' do
content'-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEAsdZdH0Hq2cbpsoBdhrbVUYIW3oc5uj3ZbAD+KbgNZ4Fg2lxPn0wU
B0rMZnOiyCORpOepnTMX47zG6CwKYIaTDktnAxGpFe6VB5m5IZgUwjKBDwYRAa9Q
rhL0SEpBmXbB9uN9+yBe+j60S5g+MxdQDwaLmS5G1kPpz1ccA7xIaaEKEx4pbZkY
rAdmc7eG610DijttCaiLov6AZ5KtAmza698+8tCkfWpepkjQULKmJQ8ZZVzJyKYb
4hp21PS6Xv5/Z3t7FS0Q+SLyMo3Dw2bxJTkXzAISXfb5NnRWARjw67is53p4agLz
l5tSYQW/+LtB7wNPfZ86Vcmmq8OM2VadWwIBAg==
-----END DH PARAMETERS-----
'
 mode '644'
 owner 'root'
end
directory '/etc/nginx/snippets' do
  owner 'root'
  group 'root'
  action :create
end
file '/etc/nginx/snippets/self-signed.conf' do
  content'ssl_certificate /etc/ssl/certs/server.crt;
ssl_certificate_key /etc/ssl/private/server.key;'
end
file '/etc/nginx/snippets/ssl-params.conf' do
  content 'ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";
ssl_ecdh_curve secp384r1;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# Disable preloading HSTS for now.  You can use the commented out header line that includes
# the "preload" directive if you understand the implications.
#add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";

add_header Strict-Transport-Security "max-age=63072000; includeSubdomains";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;

ssl_dhparam /etc/ssl/certs/dhparam.pem;'
  owner 'root'
  mode '0644'
end
file '/etc/nginx/sites-available/default' do
  action:delete
end
file '/etc/nginx/sites-enabled/default' do
  action:delete
end
execute 'reload nginx' do
  command 'sudo nginx -s reload'
end
