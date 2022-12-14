#!/bin/sh

#Script Name: Complete OpenSIPs installation including GUI management
#Description: This script will install OpenSIPs on a CentOS 7 server. This script will install all the necessary packages and will configure the server to run OpenSIPs Telephony Server. Once the script is executed, the server will be ready to run OpenSIPs Telephony Server and can be used as a SBC for Microsoft Teams.
#Author: Mohammad Rahman (Acknowledged by Jasdeep Bansal)
#OS Requirement: CentOS 7 - x86_64
#Note: Please use minimal OS to use this script, otherwise, there might be service/port/pid conflict.
#This is custom development project by Jasdeep Bansal & Mohammad Rahman for Microsoft Teams SBC.


#Color selection
verbose () {
	echo "${green}$1${normal}"
}
error () {
	echo "${red}$1${normal}"
	}
warning () {
	echo "${yellow}$1${normal}"
}

# check for color support
if test -t 1; then

    # see if it supports colors...
    ncolors=$(tput colors)

    if test -n "$ncolors" && test $ncolors -ge 8; then
        normal="$(tput sgr0)"
        red="$(tput setaf 1)"
        green="$(tput setaf 2)"
        yellow="$(tput setaf 3)"
    fi
fi


#Update to latest packages
verbose "Update installed packages"
sleep 3
yum update -y && yum upgrade -y
#Install epel-release and update
verbose "Install epel-release and update"
sleep 2
yum remove epel-release -y
yum update -y
yum install https://download-ib01.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y
yum update -y

#Add dependencies
verbose "Add dependencies to prepare the environment"
sleep 3
yum groupinstall core base "Development Tools" -y
yum install wget curl git nano vim expect -y
yum install python36 python36-pip python36-devel gcc mysql-devel python36-mysql python36-sqlalchemy python36-pyOpenSSL -y

# #install gcc 4.9.2
# verbose "Install gcc 4.9.2"
# sleep 3
# yum install gcc-c++ make -y
# wget http://ftp.gnu.org/gnu/gcc/gcc-4.9.2/gcc-4.9.2.tar.gz
# tar -xzf gcc-4.9.2.tar.gz
# cd gcc-4.9.2
# ./contrib/download_prerequisites
# ./configure --enable-shared --disable-multilib --enable-threads=posix --enable-languages=c,c++ --with-system-zlib --enable-libstdcxx-time=yes --enable-stage1-checking --enable-checking=release --enable-lto --enable-plugin --enable-install-libraries=yes --with-gxx-include-dir=/usr/include/c++/4.9.2
# make -j4
# make install


#SNMP
verbose "Install SNMP"
sleep 3
yum install net-snmp-libs net-snmp-utils net-snmp-libs-devel net-snmp-devel -y
echo "rocommunity public" > /etc/snmp/snmpd.conf
systemctl enable snmpd.service
systemctl start snmpd.service

#install monit for checking system status
verbose "Install monitoring tools"
sleep 3
yum install monit -y
systemctl enable monit.service
systemctl start monit.service

#Monit Password Update
verbose "Update monit password"
sleep 2
MonitPass=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
warning "Changing monit password to $MonitPass"
sleep 2
cat <<EOF >> /etc/monitrc
set httpd port 2812 and
#     use address localhost  # only accept connection from localhost (drop if you use M/Monit)
#     allow localhost        # allow localhost to connect to the server and
    allow admin:$MonitPass      # require user 'admin' with password 'monit'
EOF


#Install OpenSIPs & OpenSIPs-CLI
verbose "Install OpenSIPs & OpenSIPs-CLI"
sleep 3
warning "Starting installation..."
yum install https://yum.opensips.org/3.2/releases/el/7/x86_64/opensips-yum-releases-3.2-6.el7.noarch.rpm -y
yum install opensips opensips-cli -y

#Install Opensips Additional Packages
verbose "Install Opensips Additional Packages"
yum install opensips-* --skip-broken -y 
systemctl enable opensips.service
systemctl start opensips.service

#Update EPOLL feature in OpenSIPs
verbose "Update EPOLL feature in OpenSIPs"
sleep 3
cd /usr/src/
yum install git openssl-devel libxslt lynx -y
git clone --recursive https://github.com/OpenSIPS/opensips.git -b 3.2 opensips-3.2
yum remove libmicrohttpd libmicrohttpd-devel -y
wget https://cbs.centos.org/kojifiles/packages/libmicrohttpd/0.9.59/2.el7/x86_64/libmicrohttpd-0.9.59-2.el7.x86_64.rpm --no-check-certificate
wget https://cbs.centos.org/kojifiles/packages/libmicrohttpd/0.9.59/2.el7/x86_64/libmicrohttpd-devel-0.9.59-2.el7.x86_64.rpm --no-check-certificate
yum install  libmicrohttpd-0.9.59-2.el7.x86_64.rpm libmicrohttpd-devel-0.9.59-2.el7.x86_64.rpm -y

cd opensips-3.2
make modules=modules/httpd modules
make modules=modules/mi_http modules
make modules=modules/prometheus modules

#copy your compiled modules to opensips modules directory, then restart opensips.
cp modules/httpd/httpd.so /usr/lib64/opensips/modules
cp modules/mi_http/mi_http.so /usr/lib64/opensips/modules
cp modules/prometheus/prometheus.so /usr/lib64/opensips/modules

systemctl restart opensips.service

#Install sngrep
verbose "Install sngrep"
sleep 3
cat <<EOF > /etc/yum.repos.d/sngrep.repo
[irontec]
name=Irontec RPMs repository
baseurl=http://packages.irontec.com/centos/7/x86_64/
EOF
rpm --import http://packages.irontec.com/public.key
yum update -y && yum install sngrep -y


# #Install OpenSIPs RTPProxy Engine
# verbose "Installing OpenSIPs RTPProxy Engine"
# sleep 2
# useradd rtpproxy
# cd /usr/src
# git clone -b master https://github.com/sippy/rtpproxy.git
# git -c rtpproxy submodule update --init --recursive
# cd rtpproxy
# ./configure
# make clean alls
# make install

# warning "Adding OpenSIP RTPProxy as a service"
# cat <<EOF > /lib/systemd/system/rtpproxy.service
# [Unit]
# Description=RTPProxy media server
# After=network.target
# Requires=network.target
# [Service]
# Type=simple
# PIDFile=/var/run/rtpproxy/rtpproxy.pid
# Environment='OPTIONS= -f -L 4096 -l 0.0.0.0 -m 10000 -M 20000 -d INFO:LOG_LOCAL5'
# Restart=always
# RestartSec=5
# ExecStartPre=-/bin/mkdir /var/run/rtpproxy
# ExecStartPre=-/bin/chown rtpproxy:rtpproxy /var/run/rtpproxy
# ExecStart=/usr/local/bin/rtpproxy -p /var/run/rtpproxy/rtpproxy.pid -s udp:127.0.0.1:22222 \
#  -u rtpproxy:rtpproxy -n udp:127.0.0.1:22223 $OPTIONS
# ExecStop=/usr/bin/pkill -F /var/run/rtpproxy/rtpproxy.pid
# ExecStopPost=-/bin/rm -R /var/run/rtpproxy
# StandardOutput=syslog
# StandardError=syslog
# SyslogIdentifier=rtpproxy
# SyslogFacility=local5
# TimeoutStartSec=10
# TimeoutStopSec=10
# [Install]
# WantedBy=multi-user.target
# EOF

# chmod +x /lib/systemd/system/rtpproxy.service 
# systemctl enable rtpproxy.service
# systemctl start rtpproxy.service


#MySQL Server & PHP Installation 
verbose "Installing MySQL Server & PHP"
sleep 3
#install MariaDB 10.3
cat <<EOF > /etc/yum.repos.d/MariaDB.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.3/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
yum install MariaDB-server MariaDB-client -y
systemctl enable mariadb.service
systemctl start mariadb.service

#Add PHP 7.3 Remi repository
yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
#Disable 5.4 and enable 7.3
yum-config-manager --disable remi-php54
yum-config-manager --enable remi-php73
#install PHP 7.3 remi repository
yum install php php-fpm php-mysqlnd php-mbstring php-mcrypt php-xml php-xmlrpc php-soap php-intl php-gd php-json php-opcache php-pdo php-pdo_mysql -y

#install apache2 and enable php7.3
yum install httpd httpd-devel httpd-tools -y
systemctl enable httpd.service
systemctl start httpd.service

verbose "Update MySQL password"
DBPASS=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
warning "Changing MySQL password to $DBPASS"
sleep 2
mysqladmin -u root password $DBPASS
mysql -u root -p$DBPASS -e "GRANT ALL PRIVILEGES ON mysql.user TO 'root'@'localhost' WITH GRANT OPTION;"
mysql -u root -p$DBPASS -e "UPDATE mysql.user SET Password=PASSWORD('$DBPASS') WHERE User='root';"
mysql -u root -p$DBPASS -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', 'localhost.localdomain');"
mysql -u root -p$DBPASS -e "DELETE FROM mysql.user WHERE User='';"
mysql -u root -p$DBPASS -e "FLUSH PRIVILEGES;"

#restart mariadb
systemctl restart mariadb.service
error "MySQL ROOT Password set to $DBPASS"

sleep 2

#Update PHP Settings
verbose "Update PHP Settings"
sleep 2
sed 's#post_max_size = .*#post_max_size = 80M#g' -i /etc/php.ini
sed 's#upload_max_filesize = .*#upload_max_filesize = 80M#g' -i /etc/php.ini
sed 's#;max_input_vars = .*#max_input_vars = 8000#g' -i /etc/php.ini


verbose "Cloning OpenSIPs GUI interface"
#Clone GUI files to /var/www/html/ (default Apache directory)
git clone https://github.com/OpenSIPS/opensips-cp.git /var/www/html/opensips-cp
#Change ownership & permissions
chown -R apache:apache /var/www/html/opensips-cp
cd /var/www/html/opensips-cp/
#Copy the cron file to cron.d
cp config/tools/system/smonitor/opensips_stats_cron /etc/cron.d/opensips_stats_cron
#Change ownership & permissions
chown root:root /etc/cron.d/opensips_stats_cron
chmod 0644 /etc/cron.d/opensips_stats_cron
#Restart crond
systemctl restart crond.service

#OpenSIPs CLI configuration
verbose "Configuring OpenSIPs CLI"

cat << EOF > ~/.opensips-cli.cfg
[default]
 log_level: WARNING
 prompt_name: opensips-cli
 prompt_intro: Welcome to OpenSIPS at SECUREVOIP
 prompt_emptyline_repeat_cmd: False
 history_file: ~/.opensips-cli.history
 history_file_size: 1000
 output_type: pretty-print
 communication_type: fifo
 fifo_file: /tmp/opensips_fifo
 database_admin_url: mysql://root:$DBPASS@localhost
 database_url: mysql://opensips:$DBPASS@localhost
 database_name: opensips
 database_modules: ALL
 database_force_drop=true
EOF
touch ~/.opensips-cli.cfg

opensips-cli -x database create
#import database schema
mysql -u root -p$DBPASS -Dopensips < /var/www/html/opensips-cp/config/db_schema.mysql
sed -i "s/$config->db_pass = .*/$config->db_pass = \"$DBPASS\";/g" /var/www/html/opensips-cp/config/db.inc.php
verbose "Installation has been completed"
ip=$(hostname -I | awk '{print $1}')
verbose "Please visit http://$ip/opensips-cp/web/ and start configuring your opensips"
warning "Default username: admin & password: opensips, Please change it immediately."
verbose "Please keep this information in your record for further configuration"
verbose "MySQL ROOT Password: $DBPASS"
verbose	"OpenSIP DB Name: opensips, DB Username: opensips & DB Password: $DBPASS"
verbose "Monit Username: admin and Password: $MonitPass"
error "If you face any issue on deployment or in configuration, please feel free to contact to Mohammad / Jasdeep. Thank you."