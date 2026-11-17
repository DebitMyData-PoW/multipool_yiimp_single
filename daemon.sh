#####################################################
# What a coin daemon build needs on this server: DMD Core 1.3 (Bitcoin Core 31 based) builds
# with CMake. The daemon itself is built and set up apart from this install.
#
# Created by cryptopool.builders for crypto use. Updated by DebitMyData for its pool.
#####################################################

source /etc/functions.sh
source /etc/multipool.conf
source "$STORAGE_ROOT/yiimp/.yiimp.conf"

echo -e " Installing what a coin daemon build needs...$COL_RESET"
apt_install build-essential cmake pkgconf python3 git \
	libevent-dev libboost-dev libsqlite3-dev libzmq3-dev systemtap-sdt-dev \
	capnproto libcapnp-dev

sudo mkdir -p "$STORAGE_ROOT/yiimp/yiimp_setup/tmp"
echo -e "$GREEN Daemon build tools installed...$COL_RESET"

cd "$HOME/multipool/yiimp_single" || exit 1
