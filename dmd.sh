#!/usr/bin/env bash
#####################################################
# DebitMyData's part of the pool, as it runs on pool.debitmydata.io:
# - the DMD stratum (SHA-256) on its own port, with PPLNS and solo (m=solo in the password)
#   paid in the block itself, and the firewall open on that port;
# - the pool app's notifications (web push): their key pair, their settings and their service.
#
# The database part (PPLNS, notifications) is in db.sh; the admin portal's password in web.sh.
# By DebitMyData for its pool.
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"

SITE="$STORAGE_ROOT/yiimp/site"
STRATUM_CONFIG="$SITE/stratum/config"
CONFIG_DIR="$SITE/configuration"
INSTALL_DIR="$HOME/multipool/yiimp_single"

echo -e " Setting up the DMD stratum on port ${StratumPort}...$COL_RESET"
cd "$STRATUM_CONFIG" || exit 1
cp sha.conf dmd.sha.conf
sed -i "s/^port = .*/port = ${StratumPort}/" dmd.sha.conf
sed -i '/^\[STRATUM\]/a diff_max = 1073741824' dmd.sha.conf
cat >> dmd.sha.conf <<'CONF'

[WALLETS]
include = DMD

# PPLNS and solo (m=solo in the password), paid in the block itself (stratum/pplns.cpp).
# fee: the pool's fee in percent, the same as YAAMP_FEES_MINING (configuration/serverconfig.php)
# and $fee_pool on the home page; solo_fee: the same as $fee_solo there.
[PPLNS]
enable = 1
window = 2
fee = 0.5
solo = 1
solo_fee = 1
max_outputs = 50
min_output = 0.1
check_template = 1
CONF
chmod 640 dmd.sha.conf
# Only the DMD stratum mines DMD.
printf '\n[WALLETS]\nexclude = DMD\n' >> sha.conf

ufw_allow "${StratumPort}/tcp"
echo -e "$GREEN DMD stratum set up...$COL_RESET"

echo -e " Setting up the pool app's notifications...$COL_RESET"
cd "$CONFIG_DIR" || exit 1
# The key pair. A new key means every device turns notifications on again: an existing one stays.
if [ ! -f push-vapid.pem ]; then
	hide_output sudo openssl ecparam -name prime256v1 -genkey -noout -out push-vapid.pem
fi
# Readable only by the user of the blocks job (this user).
sudo chown "$(id -un):$(id -gn)" push-vapid.pem
sudo chmod 600 push-vapid.pem
PUSH_PUBLIC=$(openssl ec -in push-vapid.pem -pubout -outform DER 2>/dev/null |
	tail -c 65 | base64 -w0 | tr '/+' '_-' | tr -d '=')
if [ "${#PUSH_PUBLIC}" -ne 87 ]; then
	echo "FAILED: the notifications' public key could not be read from $CONFIG_DIR/push-vapid.pem"
	exit 1
fi
sudo tee push.php >/dev/null <<PHP
<?php
// The pool app's notifications (web push), written by the installer (multipool_yiimp_single/dmd.sh).
// The private key is in push-vapid.pem next to this file, readable only by the user that runs
// the blocks job. A new key means every device turns notifications on again: keep both files
// when the pool moves to a new server.
define('PUSH_VAPID_PUBLIC', '${PUSH_PUBLIC}');
define('PUSH_VAPID_PRIVATE_FILE', __DIR__ . '/push-vapid.pem');
define('PUSH_SUBJECT', 'https://${DomainName}');
PHP
sudo chown "$(id -un):www-data" push.php
sudo chmod 644 push.php

# The service that sends them (within about 2 seconds); without it, the blocks job sends them
# every 30 seconds. It starts with the server.
sed -e "s|__JOBS_USER__|$(id -un)|g" -e "s|__SITE__|${SITE}|g" "$INSTALL_DIR/ubuntu/dmd-pool-push.service" |
	sudo tee /etc/systemd/system/dmd-pool-push.service >/dev/null
if [ -d /run/systemd/system ]; then
	hide_output sudo systemctl daemon-reload
	hide_output sudo systemctl enable dmd-pool-push
else
	echo -e "$YELLOW systemd is not running here: enable dmd-pool-push.service yourself (sudo systemctl enable --now dmd-pool-push).$COL_RESET"
fi
echo -e "$GREEN Notifications set up...$COL_RESET"

cd "$INSTALL_DIR" || exit 1
