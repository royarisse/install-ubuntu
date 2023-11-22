#!/bin/bash
# Start with a fresh download of Ubuntu Gnome
# Use unetbootin to put it onto an SD card
# Ensure to at encrypt the entire disk
# Also use minimal installation

# Enforce root
if [[ $EUID -eq 0 ]]; then
   echo "This script must be run as it's final user, not as root!"
   exit 1
fi


################################################################################
# ===================== INITIAL SETUP AND PACKAGES =============================
################################################################################


# Update
sudo apt update
sudo apt upgrade -y
sudo apt install -y software-properties-common # for add-apt-repository

# Repo: keepassxc
sudo add-apt-repository ppa:phoerious/keepassxc
# Repo: Sublime Text
# https://www.sublimetext.com/docs/linux_repositories.html
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
# Repo: Spotify
curl -sS https://download.spotify.com/debian/pubkey_7A3A762FAFD4A51F.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
# Repo: Ondrej PHP
sudo add-apt-repository ppa:ondrej/php
# Repo: Mariadb Community
# https://mariadb.com/docs/deploy/deployment-methods/repo/
wget https://downloads.mariadb.com/MariaDB/mariadb_repo_setup
chmod +x mariadb_repo_setup
sudo ./mariadb_repo_setup
# Firefox / Thunderbird
sudo add-apt-repository ppa:mozillateam/ppa

# Firefox
echo '
Package: *
Pin: release o=LP-PPA.mozillateam
Pin-Priority: 1001

Package: Firefox
Pin: version 1:1snap1-Ubuntu2
Pin-Priority -1' | sudo tee /etc/apt/preferences.d/mozilla-firefox

#sudo apt remove -y gnome-shell-extension-ubuntu-dock update-notifier tracker
sudo apt-get remove --purge unattended-upgrades snapd
sudo apt-mark hold unattended-upgrades snapd
sudo apt autoremove

# Install basic utilities
# About preload: https://itsfoss.com/improve-application-startup-speed-with-preload-in-ubuntu/
sudo apt install -y arp-scan bash-completion bc cifs-utils colordiff curl \
 dconf-editor default-jdk dnsutils dos2unix firefox gdebi gimp git gnome-sushi \
 gparted htop hunspell-nl imagemagick jq keepassxc libreoffice \
 libreoffice-l10n-nl lm-sensors mariadb-server meld mtools nginx nmap \
 openssh-server parallel pv redis rsync spotify-client sublime-text telnet \
 terminator thunderbird thunderbird-locale-nl tnef ufw vlc w3m wget whois \
 xclip zsh

# Update nodifier
# https://askubuntu.com/a/1322357
# !!! Breaks Ubuntu-Desktop metapackage but that's fine until dist-upgrade
sudo apt remove update-notifier update-manager

# We can't delete packagekit, so we disable it
sudo systemctl stop packagekit
sudo systemctl disable packagekit

# Tracker can't be removed so just disable it
systemctl --user mask tracker-store.service tracker-miner-fs.service \
  tracker-miner-rss.service tracker-extract.service \
  tracker-miner-apps.service tracker-writeback.service

# Enable verbose boot process
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT=""/g' /etc/default/grub
sudo update-grub

# Install required drivers
ubuntu-drivers autoinstall

# Beyond compare
wget https://www.scootersoftware.com/files/bcompare-4.4.7.28397_amd64.deb
sudo gdebi -n bcompare-*.deb

################################################################################
# =================== SYSTEM AND SECURITY SETTINGS =============================
################################################################################


# Firewall: security first
sudo ufw enable
sudo ufw default deny incoming
sudo ufw allow proto tcp from $(dig +short A bootstrap.perfacilis.com) to any port 22 comment "Bootstrap"
sudo ufw allow proto tcp from $(dig +short AAAA bootstrap.perfacilis.com) to any port 22 comment "Bootstrap"
sudo ufw limit proto tcp from 192.168.178.0/24 to any port 22 comment "SSH local network"
sudo ufw allow in on tun0 comment "TryHackMe"
sudo ufw logging medium

## No automount, for no-one
sudo mkdir -p /etc/dconf/db/local.d/
echo "[org/gnome/desktop/media-handling]
automount=false
automount-open=false" | sudo tee /etc/dconf/db/local.d/00-media-automount

# Speed improvements
# 1. Remove support for non-English packages
# 2. Reduce swappiness (https://www.youtube.com/watch?v=f0pNgK2Em-M)
echo "Acquire::Languages \"none\";" | sudo tee /etc/apt/apt.conf.d/00aptitude
echo "vm.swappiness = 10" | sudo tee /etc/sysctl.conf

## DNS resolver bootstrap.perfacilis.com
echo "DNS=$(dig +short bootstrap.perfacilis.com)" | sudo tee -a /etc/systemd/resolved.conf
echo "FallbackDNS=1.1.1.3 1.0.0.3" | sudo tee -a /etc/systemd/resolved.conf
sudo service systemd-resolved restart

# Firefox extensions
wget https://addons.mozilla.org/firefox/downloads/file/3961087/ublock_origin-latest.xpi -O ublock_origin-latest.xpi
firefox ublock_origin-latest.xpi
wget https://addons.mozilla.org/firefox/downloads/file/3974246/keepassxc_browser-latest.xpi -O keepassxc_browser-latest.xpi
firefox keepassxc_browser-latest.xpi
wget https://addons.mozilla.org/firefox/downloads/file/3616824/foxyproxy_standard-latest.xpi -O foxyproxy_standard-latest.xpi
firefox foxyproxy_standard-latest.xpi
rm *.xpi

# KeePassX settings, to ensure db locks itself
mkdir -p ~/.config/keepassx
echo "[security]
clearclipboard=true
clearclipboardtimeout=10
lockdatabaseidle=true
lockdatabaseidlesec=1800
passwordscleartext=false
autotypeask=true" > ~/.config/keepassx/keepassx2.ini


################################################################################
# =========================== LOOK AND FEEL ====================================
################################################################################

# https://www.reddit.com/r/pop_os/comments/eln8bp/screen_going_black_after_30_seconds/
if xset -dpms 2>/dev/null; then
  echo '' >> ~/.zshrc
  echo '# Disable screen blank 30 seconds' >> ~/.zshrc
  echo '# /media/$USER/smb-royarisse/tools/install-popos.sh' >> ~/.zshrc
  echo 'xset -dpms' >> ~/.zshrc
fi

# DIsable Discover to show those pesky update messages
# https://www.reddit.com/r/kde/comments/dj4svw/how_to_get_rid_of_discover_notifier/f4g9ces/
mkdir ~/.config/autostart
echo 'Hidden=true' >> ~/.config/autostart/org.kde.discover.notifier.desktop

# ZSH, oh my zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

## Dracula ZSH theme
git clone https://github.com/dracula/zsh.git ~/Downloads/dracula-zsh
cp ~/Downloads/dracula-zsh/dracula.zsh-theme ~/.oh-my-zsh/themes/dracula.zsh-theme
cp -R ~/Downloads/dracula-zsh/lib ~/.oh-my-zsh/themes
echo 'ZSH_THEME=dracula' > ~/.oh-my-zsh/custom/dracula.zsh
echo 'DRACULA_DISPLAY_TIME=1' >> ~/.oh-my-zsh/custom/dracula.zsh
echo 'DRACULA_DISPLAY_CONTEXT=1' >> ~/.oh-my-zsh/custom/dracula.zsh

## Plugins
sed -i 's/^plugins\=(.*)$/plugins=(common-aliases git history-substring-search sudo web-search)/m' ~/.zshrc

# Enable red color prompt for root
# https://lifehacker.com/use-a-different-color-for-the-root-shell-prompt-5195951
sudo sed -i 's/#force_color_prompt/force_color_prompt/g' /root/.bashrc
sudo sed -i 's/033\[01;32m/033\[01;31m/g' /root/.bashrc

## Dotnet
echo 'export DOTNET_ROOT=$HOME/.dotnet' > ~/.oh-my-zsh/custom/dotnet.sh
echo 'export PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools' >> ~/.oh-my-zsh/custom/dotnet.sh

## Plugins
sed -i 's/^plugins\=(.*)$/plugins=(common-aliases debian git history-substring-search sudo web-search)/m' ~/.zshrc
omz reload

# Fonts, used for interface and development
FONTS_DIR="/home/$USER/.fonts"
mkdir "$FONTS_DIR"

TOP_FONTS=(
  "3270Medium.otf"
  "DejaVuSansMono.ttf"
  "FiraCode-Regular.ttf"
  "Inconsolata-Regular.ttf"
  "Menlo-Regular.ttf"
  "Monaco-Linux.ttf"
  "Hack/Hack-Bold.ttf"
  "Hack/Hack-BoldItalic.ttf"
  "Hack/Hack-Italic.ttf"
  "Hack/Hack-Regular.ttf"
)
for i in ${TOP_FONTS[*]}; do
    echo "Downloading $i"
    wget -qc https://github.com/hbin/top-programming-fonts/blob/master/$i?raw=true -O $(basename $i) \
      || echo "Fail to download ${i}"
    mv -f $(basename $i) $FONTS_DIR || echo "Could not install $i"
    echo "Installed $i successfully"
done

# Terminator
cd /tmp
git clone https://github.com/dracula/terminator.git
cd terminator
./install.sh
# Fix font and readability
sed -i 's/font = .*$/font = Hack 10/' ~/.config/terminator/config
sed -i 's/foreground_color = .*$/foreground_color = "#ffffff"/' ~/.config/terminator/config
sed -i 's/background_color = .*$/background_color = "#000000"/' ~/.config/terminator/config

# Gnome settings
dconf write /org/gnome/gnome-session/auto-save-session true
#dconf write /org/gnome/desktop/interface/gtk-theme "'Arc-Dark'"
dconf write /org/gnome/desktop/interface/clock-show-date true
dconf write /org/gnome/desktop/interface/clock-show-seconds true
dconf write /org/gnome/desktop/calendar/show-weekdate true
dconf write /org/gnome/mutter/attach-modal-dialogs false
dconf write /org/gnome/desktop/sound/allow-volume-above-100-percent true
#dconf write /org/gnome/shell/enabled-extensions "['alternate-tab@gnome-shell-extensions.gcampax.github.com', 'system-monitor@paradoxxx.zero.gmail.com']"
dconf write /org/gnome/desktop/input-sources/xkb-options "['compose:ralt']"
dconf write /org/gnome/settings-daemon/plugins/media-keys/home "'<Super>e'"
dconf write /org/gnome/desktop/media-handling/autorun-never true
dconf write /org/gnome/desktop/notifications/show-in-lock-screen false
dconf write /org/gnome/mutter/workspaces-only-on-primary false

# System monitor settings
dconf write /org/gnome/shell/extensions/system-monitor/center-display true
dconf write /org/gnome/shell/extensions/system-monitor/move-clock true
dconf write /org/gnome/shell/extensions/system-monitor/icon-display false
dconf write /org/gnome/shell/extensions/system-monitor/cpu-show-text false
dconf write /org/gnome/shell/extensions/system-monitor/memory-show-text false
dconf write /org/gnome/shell/extensions/system-monitor/net-show-text false
dconf write /org/gnome/shell/extensions/system-monitor/disk-display true
dconf write /org/gnome/shell/extensions/system-monitor/disk-show-text false
dconf write /org/gnome/shell/extensions/system-monitor/thermal-display true
dconf write /org/gnome/shell/extensions/system-monitor/thermal-show-text false
dconf write /org/gnome/shell/extensions/system-monitor/thermal-sensor-file "'/sys/class/hwmon/hwmon3/temp1_input'"

# System settings
dconf write /system/locale/region "'nl_NL.UTF-8'"

# Disable update notifications
dconf write /org/gnome/software/download-updates false
dconf write /org/gnome/software/download-updates-notify false
dconf write /org/gnome/software/allow-updates false

# Terminal settings
profile=$(dconf read /org/gnome/terminal/legacy/profiles:/list | cut -d"'" -f2)
dconf write /org/gnome/terminal/legacy/profiles:/:$profile/default-size-rows 28
dconf write /org/gnome/terminal/legacy/profiles:/:$profile/default-size-columns 132
dconf write /org/gnome/terminal/legacy/profiles:/:$profile/use-theme-colors false
dconf write /org/gnome/terminal/legacy/profiles:/:$profile/foreground-color "'rgb(170,170,170)'"
dconf write /org/gnome/terminal/legacy/profiles:/:$profile/background-color "'rgb(0,0,0)'"

# Disable dock (sidebar)
#gsettings set org.gnome.shell enable-hot-corners true
gsettings set org.gnome.shell.extensions.dash-to-dock autohide false
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
gsettings set org.gnome.shell.extensions.dash-to-dock intellihide false

## Sublime dictionaries
## https://github.com/titoBouzout/Dictionaries#installation
mkdir -p ~/.config/sublime-text/Packages
cd ~/.config/sublime-text/Packages
git clone https://github.com/titoBouzout/Dictionaries.git

## Sublime Dracula Theme
#cd ~/.config/sublime-text/Packages
#git clone https://github.com/dracula/sublime.git "Dracula Color Scheme"
unzip /media/$USER/smb-perfacilis/Suppliers/Dracula\ PRO/Dracula\ PRO\ -\ Zeno\ Rocha.zip -d /tmp/dracula -x "*.mp3"
mkdir ~/.config/sublime-text/Packages/Dracula\ Color\ Scheme
cp /tmp/dracula/themes/sublime/*.tmTheme ~/.config/sublime-text/Packages/Dracula\ Color\ Scheme

## Sublime settings file
mkdir ~/.config/sublime-text/Packages/User
echo '{
  "theme": "Default Dark.sublime-theme",
  "color_scheme": "Packages/Dracula Color Scheme/Dracula Pro.tmTheme",
  "dictionary": "Packages/Dictionaries/Dutch.dic",
  "highlight_line": true,
  "rulers": [ 80, 100, 120 ],
  "font_face": "Hack",
  "font_size": 10.0,
  "spell_check": true,
  "translate_tabs_to_spaces": true,
}' | tee ~/.config/sublime-text/Packages/User/Preferences.sublime-settings

# Speed improvements
# 1. Remove support for non-English packages
echo "Acquire::Languages \"none\";" | sudo tee /etc/apt/apt.conf.d/00aptitude
# 2. Reduce swappiness (https://www.youtube.com/watch?v=f0pNgK2Em-M)
echo "vm.swappiness = 10" | sudo tee /etc/sysctl.conf


################################################################################
# =========================== DEVELOPMENT TOOLS ================================
################################################################################


# Permissions
sudo usermod -a -G www-data $USER
sudo chown $USER:$USER /var/www -Rf
sudo chmod 775 /var/www -Rf

# PHP FPM for all versions and set PHP config
for v in 5.6 7.1 7.3 7.4 8.1 8.2; do
  sudo apt install -y php$v-fpm php$v-dev php$v-bcmath php$v-xml php$v-imagick \
   php$v-xdebug php$v-mbstring php$v-curl php$v-gd php$v-mysql php$v-soap \
   php$v-zip php$v-intl

  sudo mv "/etc/php/$v/fpm/pool.d/www.conf" "/etc/php/$v/fpm/pool.d/www.disabled"

  # FPM
  echo "[php-$v]
user = $USER
group = $USER
listen = /var/run/php/php-$v.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3" | sudo tee "/etc/php/$v/fpm/pool.d/$USER.conf"

  # Config
  echo "post_max_size = 256M
upload_max_filesize = 256M
error_reporting = E_ALL
display_errors = On
opcache.enable = 0
date.timezone = Europe/Amsterdam
session.gc_maxlifetime = 7200
memory_limit = 512M
max_execution_time = 300

# Show more elements in var_dump
xdebug.var_display_max_depth = 10
xdebug.var_display_max_children = 256
xdebug.var_display_max_data = 1024

# Allow creation of Phar
phar.readonly = Off

[xdebug]
xdebug.start_with_request=trigger
# 20231117 Laravel 5.5.50 (FinConnect) specific?
xdebug.mode=develop
xdebug.log=/tmp/xdebug.log
#xdebug.discover_client_host=1
#xdebug.client_host=127.0.0.1
xdebug.client_port=9003


xdebug.force_display_errors = 1
xdebug.force_error_reporting = -1
" | sudo tee "/etc/php/$v/fpm/conf.d/90-optimize.ini"

  sudo systemctl restart php$v-fpm
done

## Dbeaver community edition
## https://computingforgeeks.com/install-and-configure-dbeaver-on-ubuntu-debian/
curl -fsSL https://dbeaver.io/debs/dbeaver.gpg.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/dbeaver.gpg
echo "deb https://dbeaver.io/debs/dbeaver-ce /" | sudo tee /etc/apt/sources.list.d/dbeaver.list
sudo apt update
sudo apt install dbeaver-ce

# Composer
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '55ce33d7678c5a611085589f1f3ddf8b3c52d662cd01d4ba75c0ee0459970c2200a51f492d557530c71c15d8dba01eae') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
sudo mv composer.phar /usr/local/bin/composer

# Nodejs
# https://github.com/nodesource/distributions
#curl -fsSL https://deb.nodesource.com/setup_20.x > /tmp/install-node.sh
#sudo bash /tmp/install-node.sh
#rm /tmp/install-node.sh
#sudo apt-get install -y nodejs
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
NODE_MAJOR=20
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt update
sudo apt install nodejs -y

# Required NPM nodules
# https://sass-lang.com/install
sudo npm install -g sass

# Mysql
# https://www.linuxbabe.com/mariadb/install-mariadb-ubuntu-18-04-18-10
echo "[mysql]
auto-rehash

[mysqld]
innodb_file_per_table=1
innodb_print_all_deadlocks = 1

# https://dba.stackexchange.com/a/83385
# Faster imports
innodb_buffer_pool_size = 2G
innodb_log_buffer_size = 256M
innodb_log_file_size = 1G
innodb_write_io_threads = 16
innodb_flush_log_at_trx_commit = 0

# Enable slow query logging
slow_query_log = 1
long_query_time = 0.1
log_queries_not_using_indexes = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log" | sudo tee /etc/mysql/mariadb.conf.d/90-optimize.cnf

# Logrotate for slow queries
# https://oguya.ch/posts/2016-04-13-safely-rotating-mysql-slow-logs/
echo "/var/log/mysql/mysql-slow.log {
    dateext
    compress
    missingok
    rotate 7
    notifempty
    delaycompress
    sharedscripts
    nocopytruncate
    create 660 mysql mysql
    postrotate
        /usr/bin/mysql -e 'select @@global.slow_query_log into @sq_log_save; set global slow_query_log=off; select sleep(5); FLUSH SLOW LOGS; select sleep(10); set global slow_query_log=@sq_log_save;'
    endscript
}" | sudo tee /etc/logrotate.d/mysql-slow-logs

# Create default user
mysqlpwd="$(cat /dev/urandom | tr -dc '[:print:]' | fold -w 32 | head -n 1)"
sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO '$USER'@'localhost' IDENTIFIED BY '$mysqlpwd' WITH GRANT OPTION;"
echo "Mysql password for $(whoami)@localhost: $mysqlpwd"
