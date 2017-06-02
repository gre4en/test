#!/bin/bash

read -n 1 -p "Запустить выполнение скрипта? (y/[a]): " AMSURE 
[ "$AMSURE" = "y" ] || exit
echo "" 1>&2

firstrun=1
read -n 1 -p "Первый запуск скрипта? (y/[a]): " AMSURE 
[ "$AMSURE" = "y" ] || firstrun=0
echo "" 1>&2

sudo apt-get update

#Разворачиваем lamp-server

echo "----------Устанавливаем LAMP----------"
sudo apt-get install tasksel -y
sudo tasksel install lamp-server
echo "----------Установка LAMP завершена----------"

#Разворачиваем postfix и проводим его настройку

echo "----------Устанавливаем Postfix----------"
sudo apt-get install postfix
echo "----------Установка Postfix завершена----------"
echo "----------Настраиваем Postfix----------"
[ "$firstrun" = "0" ] || sudo sh -c "echo 'sender_dependent_default_transport_maps = regexp:/etc/postfix/sdd_transport_maps.regexp' >> /etc/postfix/main.cf"

[ "$firstrun" = "1" ] || sudo rm -r -f /etc/postfix/sdd_transport_maps.regexp
sudo touch /etc/postfix/sdd_transport_maps.regexp

#Проверка в какой файл добавлять IPV6
fileplace=/etc/network/interfaces
if [ -f "/etc/network/interfaces.d/ipv6" ]
then
  f=0
  while read line; do
    [ "$(expr match "$line" 'iface')" = "5" ] && f=1
  done < /etc/network/interfaces.d/ipv6
  if [ "$f" = "1" ]
  then
    fileplace=/etc/network/interfaces.d/ipv6
  fi
fi

while read line; do
  len=${#line}
  if [ "${line:4}" = "auto" ]
  then
    inter="${line:5:len}"
    break
  fi
done < /etc/network/interfaces

if [ "$firstrun" = "1" ]
then
  sudo rm -f /etc/network/interfaces
  sudo touch /etc/network/interfaces
  
  sudo sh -c "echo 'auto $inter' >> /etc/network/interfaces"
  sudo sh -c "echo 'iface $inter inet static' >> /etc/network/interfaces"
  sudo sh -c "echo '' >> /etc/network/interfaces"
fi
k1=0
k=1
while read line; do
  i=$(expr index $line "; ")
  j=$(expr index ${line:i} ".")
  str=${line:i}
  sudo sh -c "echo /@${str:0:j-1}'\'${str:j-1}$/ ip$k: >> /etc/postfix/sdd_transport_maps.regexp"
  if [ "$firstrun" = "1" ]
  then
    sudo sh -c "echo 'ip$k unix - - n - - smtp' >> /etc/postfix/master.cf"
    str=${line:0:i-1}
    [ "${str:4:1}" = ":" ] || sudo sh -c "echo ' -o smtp_bind_address=${line:0:i-1} ' >> /etc/postfix/master.cf"
    [ "${str:4:1}" != ":" ] || sudo sh -c "echo ' -o smtp_bind_address6=${line:0:i-1} ' >> /etc/postfix/master.cf" 
    sudo sh -c "echo ' -o smtp_helo_name=${line:i} ' >> /etc/postfix/master.cf"
    sudo sh -c "echo ' -o syslog_name=${line:i}' >> /etc/postfix/master.cf"
    sudo sh -c "echo '' >> /etc/postfix/master.cf"

    #Добавляем alias IP

    if [ "${str:4:1}" != ":" ]
    then
      sudo sh -c "echo '' >> /etc/network/interfaces"
      sudo sh -c "echo 'auto $inter:$k1' >> /etc/network/interfaces"
      sudo sh -c "echo 'iface $inter:$k1 inet static' >> /etc/network/interfaces"
      sudo sh -c "echo 'address ${line:0:i-1}' >> /etc/network/interfaces"
    fi
    if [ "${str:4:1}" = ":" ]
    then
      sudo sh -c "echo '' >> $fileplace"
      sudo sh -c "echo 'auto $inter:$k1' >> $fileplace"
      sudo sh -c "echo 'iface $inter:$k1 inet6 static' >> $fileplace"
      sudo sh -c "echo 'address ${line:0:i-1}' >> $fileplace"
      sudo sh -c "echo 'netmask 64' >> $fileplace"
    fi
  fi
  let "k=k+1"
  let "k1=k1+1"
done < ./domains-ip.txt

echo "----------Настройка Postfix завершена----------"

#Разворачиваем и настраиваем DKIM
echo "----------Устанавливаем opendkim и opendkim-tools----------"
sudo apt-get install opendkim opendkim-tools
if [ "$firstrun" = "1" ]
then
  sudo mkdir /etc/dkimkeys
  sudo opendkim-genkey -D /etc/dkimkeys -s dkim
  sudo sh -c "echo '' >> /etc/opendkim.conf"
  sudo sh -c "echo 'Domain                  *' >> /etc/opendkim.conf"
  sudo sh -c "echo 'KeyFile         /etc/dkimkeys/dkim.private' >> /etc/opendkim.conf"
  sudo sh -c "echo 'Selector                dkim' >> /etc/opendkim.conf"

  sudo sh -c "echo '' >> /etc/default/opendkim"
  sudo sh -c "echo 'SOCKET=\"inet:12345@localhost\"' >> /etc/default/opendkim"

  sudo sh -c "echo '' >> /etc/postfix/main.cf"
  sudo sh -c "echo 'milter_default_action = accept' >> /etc/postfix/main.cf"
  sudo sh -c "echo 'milter_protocol = 2' >> /etc/postfix/main.cf"
  sudo sh -c "echo 'smtpd_milters = inet:localhost:12345' >> /etc/postfix/main.cf"
  sudo sh -c "echo 'non_smtpd_milters = inet:localhost:12345' >> /etc/postfix/main.cf"
  sudo chmod 600 /etc/dkimkeys/dkim.private
  sudo chown opendkim:opendkim /etc/dkimkeys/dkim.private
fi

sudo service opendkim restart

echo "----------Перезапуск интерфейсов.----------"
sudo service networking restart
sudo postfix start
sudo postfix reload

echo "----------Настройка opendkim завершена----------"

echo "----------Проверка файла hosts----------"

sudo cp -f /etc/hosts tmp.txt
sudo rm -f /etc/hosts
sudo touch /etc/hosts
while read line; do
  [ "${line:0:9}" != "127.0.0.1" ] && [ "${line:0:3}" != "::1" ] && sudo sh -c "echo '$line' >> /etc/hosts"
done < tmp.txt
sudo sh -c "echo '127.0.0.1 localhost' >> /etc/hosts"
sudo sh -c "echo '::1 ip6-localhost ip6-loopback localhost' >> /etc/hosts"

echo "----------Файл dkim.txt:----------"
sudo tail /etc/dkimkeys/dkim.txt



echo "----------Выполнено.----------"
