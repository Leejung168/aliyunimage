#!/bin/bash
#This script major function is that how to install services automatically.
################################################################################
#2015-08-14   Lambert.Li    Define the initialization env
################################################################################
######Color define######
bold=`tput bold`
underline=`tput smul`
red=`tput setaf 1`
light_backgroud=`tput rev`
blue_backgroud=`tput setab 4`
green_backgroud=`tput setab 2`
normal=`tput sgr0`


####Loading variables####
CURRENT_DIR=$(readlink -f $(dirname $0))
SCRIPT_CONF="$CURRENT_DIR/lambert.conf"
[ -e "$SCRIPT_CONF" ] && source $SCRIPT_CONF || (echo "The variables fiel is not existent!!!" && exit 1)
################################################################################
# Collect basic information on the server
basic_info() {
    OS_VERSION=`cat /etc/issue| sed -n '1p'`
    CPU_NUMS=`grep -c "\<processor\>" /proc/cpuinfo`
    RAM_SIZE=`free -m | sed -n '2p'|awk  '{ print $2 }'`
    let RAM_INTEGER=$RAM_SIZE/1024+1
    DISK_SIZE=`echo "scale=1;$(fdisk -l  2>/dev/null | awk '{if($0~/Disk.*[shxv](\w+)?d[a-z]/) print $(NF-1)}' | awk 'BEGIN{OFMT="%.1f"} {total+=$1}END{print total/1024/1024/1024}')" | bc`
    PUBLIC_IP=`ifconfig | grep -A1 eth1 | grep  -Po '(?<=addr:)[^ ]+'`
    INTERNAL_IP=`ifconfig | grep -A1 eth0 | grep  -Po '(?<=addr:)[^ ]+'`
    #echo "${red}${light_backgroud}Basic  Information ${normal}"
    echo "============================================"
    echo "* OS Version:   $OS_VERSION"
    echo "* CPU Number:   $CPU_NUMS vcpus"
    echo "* Ram Size:     $RAM_INTEGER G "
    echo "* Disk Size:    $DISK_SIZE G"
    echo "* Public IP:    $PUBLIC_IP"
    echo "* Internal IP:  $INTERNAL_IP"
    echo "============================================"
}
#basic_info
###########################################################################################################
####This part is to install repo####
Services_Repo(){
    rpm -qa | grep "$1" &>/dev/null
    if [ $? -ne 0 ];then
       yum -y install $2; yum clean all &>/dev/null || (echo "Install $1 repo failed, please contact us quickly!!!" exit 1)
    [[ -e /etc/yum.repos.d/remi.repo ]] && $(sed -i "18s/enabled=0/enabled=1/" /etc/yum.repos.d/remi.repo)
    fi
}
############################################################################################################
####This part define what should to do after install services####
Haproxy_Config(){
#echo "Are optimizing configuration......"
sleep 3
cat >> /etc/syslog-ng/syslog-ng.conf <<END
# log config for haproxy
destination d_haproxy { file("/var/log/haproxy/haproxy.log"); };
filter f_haproxy { facility(local3) and level(notice,warn); };
log { source(s_sys); filter(f_haproxy); destination(d_haproxy); };

destination d_haproxy_err { file("/var/log/haproxy/haproxy_err.log"); };
filter f_haproxy_err { facility(local3) and level(err); };
log { source(s_sys); filter(f_haproxy_err); destination(d_haproxy_err); };

destination d_haproxy_access { file("/var/log/haproxy/haproxy_access.log"); };
filter f_haproxy_access { facility(local3) and level(info); };
log { source(s_sys); filter(f_haproxy_access); destination(d_haproxy_access); };
END
    [[ -e /etc/haproxy/errorfiles ]] || mkdir  /etc/haproxy/errorfiles   &>>$InstallLog
    mv /etc/haproxy/haproxy.cfg{,.bak}                                   &>>$InstallLog
    HAPROXY_CONF="$CURRENT_DIR/config/haproxy"                           &>>$InstallLog
    cp $HAPROXY_CONF/50x.http /etc/haproxy/errorfiles                    &>>$InstallLog
    cp $HAPROXY_CONF/haproxy.cfg /etc/haproxy/                           &>>$InstallLog
    [[ -e /var/log/haproxy ]] || mkdir /var/log/haproxy                  &>>$InstallLog
    [[ -e /etc/logrotate.d/haproxy.logrotate ]] || cp $HAPROXY_CONF/haproxy.logrotate /etc/logrotate.d/  &>>$InstallLog
    service haproxy start                                                &>>$InstallLog
    service syslog-ng reload                                             &>>$InstallLog
}

Apache_Config(){
    sleep 3
    APACHE_CONF="$CURRENT_DIR/config/httpd" &>>$InstallLog
    yum -y install mod_ssl  &>>$InstallLog     #install ssl module for apache
    mv /etc/httpd/conf/httpd.conf{,.bak}  &>>$InstallLog
    cp $APACHE_CONF/httpd.conf /etc/httpd/conf/  &>>$InstallLog
    [[ -e /etc/httpd/conf.d/www.example.com.conf ]] || cp $APACHE_CONF/www.example.com.conf  /etc/httpd/conf.d/   &>>$InstallLog
    [[ -e /etc/logrotate.d/httpd.logrotate ]] || cp $APACHE_CONF/httpd.logrotate /etc/logrotate.d/    &>>$InstallLog
    [[ -e /etc/httpd/certs/ ]] || mkdir /etc/httpd/certs    &>>$InstallLog
    [[ -e /var/log/httpd/ ]] || mkdir /var/log/httpd/  &>>$InstallLog 
    service httpd start                                                                               &>>$InstallLog   
    chkconfig httpd on                                                                                &>>$InstallLog
}

Php_Config(){
   sleep 3
   PHP_CONF="$CURRENT_DIR/config/php" &>>$InstallLog
   #install php extension 
   #yum -y install php-mysqlnd php-mcrypt php-xml php-fpm
   mv /etc/php.ini{,.bak}     &>>$InstallLog
   mv /etc/php-fpm.conf{,.bak} &>>$InstallLog
   mv /etc/php-fpm.d/www.conf{,.bak}  &>>$InstallLog
   cp $PHP_CONF/php.ini /etc  &>>$InstallLog
   cp $PHP_CONF/php-fpm.conf /etc &>>$InstallLog
   cp $PHP_CONF/www.conf /etc/php-fpm.d/ &>>$InstallLog
   service php-fpm start
   chkconfig php-fpm on
}   

Nginx_Config(){
   #echo "Are optimizing configuration......"
   sleep 3
   NGING_CONF="$CURRENT_DIR/config/nginx" &>>$InstallLog
   mv /etc/nginx/nginx.conf{,.bak} &>>$InstallLog
   cp $NGING_CONF/nginx.conf /etc/nginx  &>>$InstallLog
   cp $NGING_CONF/www.example.com.conf /etc/nginx/conf.d &>>$InstallLog
   cp -f $NGING_CONF/404.html /usr/share/nginx/html/  &>>$InstallLog
   cp -f $NGING_CONF/50x.html /usr/share/nginx/html/ &>>$InstallLog
   [[ -e /var/www/sites/example.com ]] || mkdir /var/www/sites/example.com  &>>$InstallLog
   [[ -e /etc/logrotate.d/nginx ]] || cp $NGING_CONF/nginx.logrotate /etc/logrotate.d/ &>>$InstallLog
   service nginx start
   chkconfig nginx on
}


Mysql_Config(){
  sleep 3
  MYSQL_BIN=$(which mysql)
  MYSQL_CONF="$CURRENT_DIR/config/mysql"   &>>$InstallLog
  MYSQL_ACCESS="$MYSQL_CONF/.my.cnf"
  MYSQLLOGIN="$MYSQL_BIN --defaults-extra-file=$MYSQL_ACCESS --skip-column-names"
  mv /etc/my.cnf{,.bak}   &>>$InstallLog
  cp $MYSQL_CONF/my.cnf.percona /etc/my.cnf &>>$InstallLog
  
  service mysql start
  chkconfig mysql on
  MYSQLSTATUS=$(netstat -nlpt | grep mysql | wc -l)
  if [[ $MYSQLSTATUS -eq 1  ]];then
      PASSWORD=$(whiptail --passwordbox "please set mysql root password(Keep in mind):" 8 78 --title "Init Mysql Password" 3>&1 1>&2 2>&3)
      PASSWORD2=$(whiptail --passwordbox "please enter the password again:" 8 78 --title "Init Mysql Password" 3>&1 1>&2 2>&3)
      if [[ $PASSWORD -eq $PASSWORD2 ]];then
      	$MYSQLLOGIN --silent -e "update mysql.user set password=password('$PASSWORD') where user='root';;flush privileges;;"
      fi
      # mysqladmin -u root password $PASSWORD  &>>$InstallLog
      echo "$PASSWORD"  &>/root/.mysql_root_password.conf
  else
      echo "The mysql doesn't run very well!" &>>$InstallLog
  fi
}


#############################################################################################################
####This part is to install services####
Install_Service(){
   rpm -qa | grep $@ &>/dev/null
   if [ $? -ne 0 ];then
       echo -n "Is installing $@"
       #while true;do echo -n  a;for i  in '\' '|' '/' '-';do  echo -en "\b$i";echo -en "\b."sleep 0.05 ;done ;done &
       while true;do echo -n  " ";for i  in '\' '|' '/' '-';do  echo -en "\b$i";sleep 0.05 ;done ;echo -en "\b=";done &
       echo "$@" >/tmp/service
       grep -i "percona" /tmp/service &>/dev/null
         if [ $? -eq 0 ];then
            if [[ -e /opt/SoftWare/Percona-Server.tar ]];then
              mkdir /tmp/percona56  &>>$InstallLog
              tar -xf /opt/SoftWare/Percona-Server.tar -C /tmp/percona56 &>>$InstallLog
              yum -y install /tmp/percona56/Percona*  &>>$InstallLog
              rm -rf /tmp/percona56/  &>>$InstallLog
              return
            fi
         fi
       yum -y install $@  &>>$InstallLog
       if [ $? -eq 0 ];then
           echo "$@ install complete!"   &>>$InstallLog
       fi
   else
       echo "Note!!!:The $@ service has already installed!" &>>$InstallLog
   fi
}

confirm_services() {
      echo "Welcome to use ChinaNetCloud Aliyum Image."> test_textbox
      whiptail --textbox test_textbox 12 80
    WHIPTAIL=$(whiptail --title "The services" --checklist \
      "Choose the services you want to install" 20 78 5 \
      "Haproxy" "High availability and load balancing software." ON \
      "Apache" "Ranked first Web server software." OFF \
      "Nginx" "high-performance web service." OFF \
      "PHP" "Hypertext Preprocessor." OFF \
      "Mysql" "The world's most popular open source database." OFF 3>&1 1>&2 2>&3 )
      echo $WHIPTAIL >/tmp/service.sh
      LZ=$(sed -n "/\"/p" /tmp/service.sh | sed 's/\"//g')
      for LL in $LZ;do
          case $LL in
              Nginx)Services_Repo nginx-release-centos $NginxRepo
                     Install_Service $Nginx_Version
                     Nginx_Config;;
              Apache)Install_Service $Apache_Version
                     Apache_Config;;
              PHP)Services_Repo remi-release $PhpRepo
                   Install_Service $PHPPACKAGE
                   Php_Config;;
              Mysql)Services_Repo percona-release $MysqlRepo
                    Install_Service $MYSQLPACKAGE
                    Mysql_Config;;
              T|t);;
              Haproxy)Install_Service haproxy
                     Haproxy_Config;;
         esac
     done
}
confirm_services
killall /bin/bash &>/dev/null
echo -n "All of this service have complated, Please enjoy it."


#while true;do echo -n  a;for i  in '\' '|' '/' '-';do  echo -en "\b$i";sleep 0.05 ;done ;done &
