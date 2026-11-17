#!/usr/bin/env bash
#####################################################
# blocknotify and the stratum, built from the pool's code, with their config files filled in
# (the database's login, blocknotify's password, the stratum's address).
#
# Created by cryptopool.builders for crypto use. Updated by DebitMyData for its pool.
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"

YIIMP_SRC="$STORAGE_ROOT/yiimp/yiimp_setup/yiimp"
STRATUM_DIR="$STORAGE_ROOT/yiimp/site/stratum"

echo -e " Building blocknotify and the stratum (can be long)...$COL_RESET"
blckntifypass=$(openssl rand -hex 16)
cd "$YIIMP_SRC/blocknotify" || exit 1
sudo sed -i "s/tu8tu5/${blckntifypass}/" blocknotify.cpp
hide_output sudo make -j"$(nproc)"
cd "$YIIMP_SRC/stratum/iniparser" || exit 1
hide_output sudo make -j"$(nproc)"
# No exchange code in it (the Makefile's -DNO_EXCHANGE): this pool does not trade.
cd "$YIIMP_SRC/stratum" || exit 1
hide_output sudo make -j"$(nproc)"

echo -e " Copying the stratum and its config files...$COL_RESET"
sudo mkdir -p "$STRATUM_DIR/config"
sudo cp -a config.sample/. "$STRATUM_DIR/config"
sudo install -m 755 stratum "$STRATUM_DIR/stratum"
sudo install -m 755 "$YIIMP_SRC/blocknotify/blocknotify" "$STRATUM_DIR/blocknotify"
sudo install -m 755 "$YIIMP_SRC/blocknotify/blocknotify" /usr/bin/blocknotify

# config/run.sh <algo>: runs one stratum, again if it stops
sudo rm -f "$STRATUM_DIR/config/run.sh"
echo '#!/usr/bin/env bash
source /etc/multipool.conf
source $STORAGE_ROOT/yiimp/.yiimp.conf
ulimit -n 10240
ulimit -u 10240
cd '"${STRATUM_DIR}"'
while true; do
./stratum config/$1
sleep 2
done
exec bash' | sudo tee "$STRATUM_DIR/config/run.sh" >/dev/null
sudo chmod +x "$STRATUM_DIR/config/run.sh"

# run.sh <algo>, from the stratum's folder
echo '#!/usr/bin/env bash
source /etc/multipool.conf
source $STORAGE_ROOT/yiimp/.yiimp.conf
cd '"${STRATUM_DIR}"'/config/ && ./run.sh $*
' | sudo tee "$STRATUM_DIR/run.sh" >/dev/null
sudo chmod +x "$STRATUM_DIR/run.sh"

echo -e " Filling in the stratum config files...$COL_RESET"
cd "$STRATUM_DIR/config" || exit 1
sudo sed -i "s/password = tu8tu5/password = ${blckntifypass}/g" ./*.conf
sudo sed -i "s/server = yaamp.com/server = ${StratumURL}/g" ./*.conf
sudo sed -i 's/host = yaampdb/host = localhost/g' ./*.conf
sudo sed -i 's/database = yaamp/database = yiimpfrontend/g' ./*.conf
sudo sed -i 's/username = root/username = stratum/g' ./*.conf
sudo sed -i "s/password = patofpaq/password = ${StratumUserDBPassword}/g" ./*.conf

# The install user runs the stratum; the config files hold the database password: only that
# user (and the www-data group it is in) reads them.
sudo chown -R "$(id -un):www-data" "$STRATUM_DIR"
sudo chmod 640 "$STRATUM_DIR"/config/*.conf

echo -e "$GREEN Stratum build complete...$COL_RESET"
cd "$HOME/multipool/yiimp_single" || exit 1
