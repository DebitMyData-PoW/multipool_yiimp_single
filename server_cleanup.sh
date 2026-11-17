#!/usr/bin/env bash
#####################################################
# What starts with the server (this user's crontab): the jobs' screens (main, loop2, blocks,
# debug) and the DMD stratum. Then the setup files (the pool's code as downloaded) are removed.
#
# Created by cryptopool.builders for crypto use. Updated by DebitMyData for its pool.
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"
cd "$HOME/multipool/yiimp_single" || exit 1

echo -e " Adding the screens to the crontab...$COL_RESET"
# Once each, even if the install runs again
{
	crontab -l 2>/dev/null | grep -v -e 'yiimp/starts/screens.start.sh' -e 'yiimp/starts/stratum.start.sh' \
		-e '@reboot source /etc/functions.sh' -e '@reboot source /etc/multipool.conf'
	echo "@reboot sleep 20 && ${STORAGE_ROOT}/yiimp/starts/screens.start.sh"
	echo "@reboot sleep 20 && ${STORAGE_ROOT}/yiimp/starts/stratum.start.sh"
} | crontab -
sudo cp -r first_boot.sh "$STORAGE_ROOT/yiimp/"
echo -e "$GREEN Crontab system complete...$COL_RESET"

echo -e " Creating the screens' start script...$COL_RESET"
echo '#!/usr/bin/env bash
source /etc/multipool.conf
source $STORAGE_ROOT/yiimp/.yiimp.conf
# On the first boot only: the log file the admin needs
if [[ -e $STORAGE_ROOT/yiimp/first_boot.sh ]]; then
source $STORAGE_ROOT/yiimp/first_boot.sh
fi
################################################################################
# Program: the YiiMP jobs'"'"' screens (main, loop2, blocks, debug), started at boot
################################################################################
sudo chmod 777 $STORAGE_ROOT/yiimp/site/log/.
sudo chmod 777 $STORAGE_ROOT/yiimp/site/log/debug.log
LOG_DIR=$STORAGE_ROOT/yiimp/site/log
CRONS=$STORAGE_ROOT/yiimp/site/crons
screen -dmS main bash $CRONS/main.sh
screen -dmS loop2 bash $CRONS/loop2.sh
screen -dmS blocks bash $CRONS/blocks.sh
screen -dmS debug tail -f $LOG_DIR/debug.log
' | sudo -E tee "$STORAGE_ROOT/yiimp/starts/screens.start.sh" >/dev/null 2>&1
sudo chmod +x "$STORAGE_ROOT/yiimp/starts/screens.start.sh"

echo -e " Creating the stratum's start script...$COL_RESET"
echo '#!/usr/bin/env bash
################################################################################
# Program: the stratums started at boot, each in its screen. The DMD stratum only: to run
# another one, add a line like the one below (stratum/config/<name>.conf), and open its port
# (sudo ufw allow <port>).
################################################################################
source /etc/multipool.conf
source $STORAGE_ROOT/yiimp/.yiimp.conf
STRATUM_DIR=$STORAGE_ROOT/yiimp/site/stratum
screen -dmS dmd bash $STRATUM_DIR/run.sh dmd.sha
' | sudo -E tee "$STORAGE_ROOT/yiimp/starts/stratum.start.sh" >/dev/null 2>&1
sudo chmod +x "$STORAGE_ROOT/yiimp/starts/stratum.start.sh"

echo '
source /etc/multipool.conf
source $STORAGE_ROOT/yiimp/.yiimp.conf
LOG_DIR=$STORAGE_ROOT/yiimp/site/log
CRONS=$STORAGE_ROOT/yiimp/site/crons
STRATUM_DIR=$STORAGE_ROOT/yiimp/site/stratum
' | sudo -E tee "$STORAGE_ROOT/yiimp/.prescreens.start.conf" >/dev/null 2>&1

for line in "source /etc/multipool.conf" "source $STORAGE_ROOT/yiimp/.prescreens.start.conf"; do
	grep -qxF "$line" ~/.bashrc 2>/dev/null || echo "$line" >> ~/.bashrc
done
echo -e "$GREEN YiiMP Screens added...$COL_RESET"

sudo rm -rf "$STORAGE_ROOT/yiimp/yiimp_setup"
cd "$HOME/multipool/yiimp_single" || exit 1
