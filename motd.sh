#####################################################
# The login screen (motd: the jobs' screens, running or stopped) and the pool's commands:
# motd, screens, stratum, addport.
#
# Created by cryptopool.builders for crypto use. Updated by DebitMyData for its pool.
#####################################################

source /etc/functions.sh # load our functions
source /etc/multipool.conf

apt_install lsb-release figlet update-motd landscape-common update-notifier-common
cd "$HOME/multipool/yiimp_single/ubuntu/etc/update-motd.d" || exit 1
sudo rm -r /etc/update-motd.d/
sudo mkdir /etc/update-motd.d/
sudo cp -r 00-header 10-sysinfo 90-footer /etc/update-motd.d/
sudo chmod +x /etc/update-motd.d/*

cd "$HOME/multipool/yiimp_single/ubuntu" || exit 1
# copy additional files
sudo cp -r screens /usr/bin/
sudo chmod +x /usr/bin/screens
sudo cp -r stratum /usr/bin
sudo chmod +x /usr/bin/stratum
sudo cp -r addport /usr/bin
sudo chmod +x /usr/bin/addport
echo '
clear
run-parts /etc/update-motd.d/ | sudo tee /etc/motd
' | sudo -E tee /usr/bin/motd >/dev/null 2>&1

sudo chmod +x /usr/bin/motd
cd "$HOME/multipool/yiimp_single" || exit 1
