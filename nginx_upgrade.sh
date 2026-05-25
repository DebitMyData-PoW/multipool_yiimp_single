#####################################################
# Created by cryptopool.builders-OLD-VERSION for crypto use...
#####################################################

source /etc/functions.sh
source $STORAGE_ROOT/yiimp/.yiimp.conf
cd $HOME/multipool/yiimp_single

# NGINX install
echo -e " Installing NGINX...$COL_RESET"

# Remove any old nginx.org repositories
sudo rm -f /etc/apt/sources.list.d/nginx.list >/dev/null 2>&1

hide_output sudo apt-get update

apt_install nginx

sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old 2>/dev/null

sudo cp -r nginx_confs/nginx.conf /etc/nginx/

sudo rm -f /etc/nginx/conf.d/default.conf
sudo rm -f /etc/nginx/sites-available/default
sudo rm -f /etc/nginx/sites-enabled/default

echo -e "$GREEN NGINX installation complete...$COL_RESET"

restart_service nginx
restart_service php7.4-fpm

cd $HOME/multipool/yiimp_single
