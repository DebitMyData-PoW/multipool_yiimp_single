# multipool_yiimp_single

The DebitMyData pool's install on one server: YiiMP with DebitMyData's changes
([debitmydata-yiimp](https://github.com/DebitMyData-PoW/debitmydata-yiimp)), on Ubuntu 24.04 with
PHP 8.3. It does nothing on its own: start from
[DebitMyData-PoW/Multi-Pool-Installer](https://github.com/DebitMyData-PoW/Multi-Pool-Installer).

`start.sh` runs these steps in order:

| File | What it does |
| --- | --- |
| `questions.sh` | The questions; the answers go to `/home/crypto-data/yiimp/.yiimp.conf` (only the install user reads it) |
| `system.sh` | Updates, Ubuntu's PHP 8.3, nginx, memcached, the build tools, the firewall; downloads the pool's code |
| `db.sh` | MariaDB 10.11, the database and its two users, YiiMP's tables, then DebitMyData's (PPLNS, notifications) |
| `nginx_upgrade.sh` | nginx's main config (`nginx_confs/nginx.conf`) |
| `web.sh` | The website, its nginx site (`nginx_confs/`, `nginx_site.sh`), the admin portal's password, Cloudflare's real IPs, the settings, the jobs |
| `https.sh` | HTTPS from Let's Encrypt (run from `web.sh`; run it again later if Let's Encrypt refused) |
| `stratum.sh` | Builds blocknotify and the stratum; fills in their config files |
| `dmd.sh` | The DMD stratum port with PPLNS (`dmd.sha.conf`), the firewall open on it, the notifications' keys and service |
| `daemon.sh` | What a coin daemon build needs (DMD Core 1.3: CMake) |
| `server_cleanup.sh` | Starts the jobs and the DMD stratum at boot; removes the setup files |
| `motd.sh` | The login screen and the `motd`, `screens`, `stratum`, `addport` commands (`ubuntu/`) |
| `server_harden.sh` | Network tuning (`/etc/sysctl.d/60-yiimp.conf`) |

The pool's code comes from the `ubuntu-24.04` branch of debitmydata-yiimp until it is merged
into `next` (`YiiMPBranch` in `questions.sh`; `YIIMP_REF=<branch> multipool` picks another one).

Based on the installer by cryptopool.builders (Original-Tasty) and le2Ks, itself based on
[Mail-in-a-Box](https://github.com/mail-in-a-box/mailinabox).
