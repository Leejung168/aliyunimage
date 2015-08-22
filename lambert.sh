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
    fi
}
############################################################################################################
####This part define what should to do after install services####
Haproxy_Config(){
echo "Are optimizing configuration......"
sleep 5
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
echo "All of haproxy related config have done. Please enjoy the use of it."
}

Apache_Config(){
echo "Are optimizing configuration......"
sleep 5
    APACHE_CONF="$CURRENT_DIR/config/httpd" &>>$InstallLog
    yum -y install mod_ssl  &>>$InstallLog     #install ssl module for apache
    mv /etc/httpd/conf/httpd.conf{,.bak}  &>>$InstallLog
    cp $APACHE_CONF/httpd.conf /etc/httpd/conf/  &>>$InstallLog
    [[ -e /etc/httpd/conf.d/www.example.com.conf ]] || cp $APACHE_CONF/www.example.com.conf  /etc/httpd/conf.d/   &>>$InstallLog
    [[ -e /etc/logrotate.d/httpd.logrotate ]] || cp $APACHE_CONF/httpd.logrotate /etc/logrotate.d/    &>>$InstallLog
    [[ -e /var/log/httpd/ ]] || mkdir /var/log/httpd/  &>>$InstallLog 
    service httpd start                                                                               &>>$InstallLog   
    chkconfig httpd on                                                                                &>>$InstallLog
    echo "All of apache related config have done. Please enjoy the use of it."
    
}

#############################################################################################################
####This part is to install services####
Install_Service(){
   rpm -qa | grep $1 &>/dev/null
   if [ $? -ne 0 ];then
       echo "Is installing $1........."
       yum -y install $1 &> $InstallLog
       if [ $? -eq 0 ];then
           echo "$1 install complete!" 
       fi
   else
       echo "Note!!!:The $1 service has already installed!"
   fi
}

confirm_services() {
    WHIPTAIL=$(whiptail --title "The services" --checklist \
      "Choose the services you want to install" 20 78 5 \
      "Haproxy" "High availability and load balancing software." ON \
      "Apache" "Ranked first Web server software." OFF \
      "Nginx" "high-performance web service." OFF \
      "PHP-FPM" "Hypertext Preprocessor." OFF \
      "Mysql" "The world's most popular open source database." OFF 3>&1 1>&2 2>&3 )
      echo $WHIPTAIL >/tmp/service.sh
      LZ=$(sed -n "/\"/p" /tmp/service.sh | sed 's/\"//g')
      for LL in $LZ;do
          case $LL in
              Apache)Install_Service $Apache_Version
                     Apache_Config;;
              Nginx)Services_Repo nginx-release-centos $NginxRepo
                    Install_Service $Nginx_Version;;
              PHP-FPM)Services_Repo remi-release $PhpRepo
                    Install_Service $PHP_Version;;
              Mysql)Services_Repo percona-release $MysqlRepo
                    Install_Service  Percona-Server;;
              T|t);;
              Haproxy)Install_Service haproxy
                     Haproxy_Config;;
         esac
     done
}
confirm_services
