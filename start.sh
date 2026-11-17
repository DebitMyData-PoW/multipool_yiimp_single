#!/usr/bin/env bash
#####################################################
# The YiiMP single server install (the DebitMyData pool): the questions first, then every step
# in order. Started by multipool_setup's menu (bootstrap_single.sh), as the install user.
#
# Source https://mailinabox.email/ https://github.com/mail-in-a-box/mailinabox
# Updated by cryptopool.builders for crypto use, and by DebitMyData for its pool.
#####################################################

source /etc/functions.sh # load our functions
source /etc/multipool.conf

# Ensure Python reads/writes files in UTF-8.
if ! locale -a | grep en_US.utf8 > /dev/null; then
	hide_output sudo locale-gen en_US.UTF-8
fi

export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_TYPE=en_US.UTF-8

# So that line drawing characters show correctly in PuTTY on Windows.
export NCURSES_NO_UTF8_ACS=1

# The install's folders.
echo -e " Creating the YiiMP folders...$COL_RESET"
sudo mkdir -p "$STORAGE_ROOT/yiimp/yiimp_setup" "$STORAGE_ROOT/yiimp/site/web" \
	"$STORAGE_ROOT/yiimp/site/stratum" "$STORAGE_ROOT/yiimp/site/configuration" \
	"$STORAGE_ROOT/yiimp/site/crons" "$STORAGE_ROOT/yiimp/site/log" \
	"$STORAGE_ROOT/yiimp/starts" "$STORAGE_ROOT/wallets"
echo -e "$GREEN Folders created...$COL_RESET"

cd "$HOME/multipool/yiimp_single" || exit 1
source questions.sh
source system.sh     # system packages, PHP, the firewall, the pool's code
source db.sh         # MariaDB, the database and its users
source nginx_upgrade.sh  # nginx's main config
source web.sh        # the website, its nginx site, SSL, the admin password, the jobs
source stratum.sh    # blocknotify and the stratum
source dmd.sh        # DebitMyData: the DMD stratum port with PPLNS, the notifications
source daemon.sh     # what a coin daemon build needs
source server_cleanup.sh  # start at boot, then the setup files are removed
source motd.sh       # the login screen and the screens/stratum commands
source server_harden.sh   # network tuning
source "$STORAGE_ROOT/yiimp/.yiimp.conf"

clear
echo "The DebitMyData pool (YiiMP single server) is installed."
echo
echo -e "You $RED*MUST REBOOT*$COL_RESET the server now (type: sudo reboot): the jobs and the stratum start at boot."
echo
echo -e "$YELLOW After the reboot,$COL_RESET wait about a minute for the main, loop2, blocks and debug screens to start,"
echo -e "then type$GREEN motd$COL_RESET to see them."
echo
if [[ "$InstallSSL" == "yes" ]]; then
	echo -e "The admin portal:$BLUE https://${DomainName}/site/AdminPortal $COL_RESET"
else
	echo -e "The admin portal:$BLUE http://${DomainName}/site/AdminPortal $COL_RESET"
fi
echo "Its user name and password, and the database passwords, are in $STORAGE_ROOT/yiimp/.yiimp.conf"
echo "(readable only by $(id -un))."
echo
echo -e "The DMD stratum listens on port ${StratumPort}, open in the firewall. Other ports stay closed:"
echo -e "to open one, type$GREEN sudo ufw allow <port>$COL_RESET."
echo
echo "Next: the DMD node, then the DMD coin in the admin (see the installer's README, \"After the install\")."
exit 0
