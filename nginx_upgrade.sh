#####################################################
# nginx's main config (nginx_confs/nginx.conf), with Ubuntu's default site removed.
#
# Created by cryptopool.builders for crypto use. Updated by DebitMyData for its pool.
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
cd "$HOME/multipool/yiimp_single" || exit 1

echo -e " Setting up NGINX...$COL_RESET"
# Remove any old nginx.org repositories: Ubuntu 24.04's own nginx is the one used
sudo rm -f /etc/apt/sources.list.d/nginx.list >/dev/null 2>&1
apt_install nginx

if [ -f /etc/nginx/nginx.conf ] && [ ! -f /etc/nginx/nginx.conf.old ]; then
	sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
fi
sudo cp nginx_confs/nginx.conf /etc/nginx/nginx.conf

sudo rm -f /etc/nginx/conf.d/default.conf
sudo rm -f /etc/nginx/sites-available/default
sudo rm -f /etc/nginx/sites-enabled/default

restart_service nginx
restart_service "php${PHP_VERSION}-fpm"
echo -e "$GREEN NGINX set up...$COL_RESET"

cd "$HOME/multipool/yiimp_single" || exit 1
