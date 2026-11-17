#####################################################
# Network tuning for the pool: TCP BBR and larger buffers, in their own file
# (/etc/sysctl.d/60-yiimp.conf, the same on every run).
# Source various web sources:
# https://www.linuxbabe.com/ubuntu/enable-google-tcp-bbr-ubuntu
# https://www.cyberciti.biz/faq/linux-tcp-tuning/
# Created by cryptopool.builders for crypto use. Updated by DebitMyData for its pool.
#####################################################

source /etc/functions.sh
source /etc/multipool.conf

echo -e " Tuning the network for YiiMP...$COL_RESET"
printf '%s\n' \
	'# Network tuning for the pool (multipool_yiimp_single/server_harden.sh)' \
	'net.core.default_qdisc = fq' \
	'net.ipv4.tcp_congestion_control = bbr' \
	'net.core.wmem_max = 12582912' \
	'net.core.rmem_max = 12582912' \
	'net.ipv4.tcp_rmem = 10240 87380 12582912' \
	'net.ipv4.tcp_wmem = 10240 87380 12582912' \
	'net.ipv4.tcp_window_scaling = 1' \
	'net.ipv4.tcp_timestamps = 1' \
	'net.ipv4.tcp_sack = 1' \
	'net.ipv4.tcp_no_metrics_save = 1' \
	'net.core.netdev_max_backlog = 5000' |
	sudo tee /etc/sysctl.d/60-yiimp.conf >/dev/null
sudo sysctl -q -p /etc/sysctl.d/60-yiimp.conf >/dev/null 2>&1 || true
echo -e "$GREEN Tuning complete...$COL_RESET"
cd "$HOME/multipool/yiimp_single" || exit 1
