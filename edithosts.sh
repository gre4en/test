#!/bin/bash

firstline=0
secondline=0
while read line; do
  [ "${line:0:9}" = "127.0.0.1" ] && [ "${line:(-9)}" = "localhost" ] && firstline=1
  if [ "${line:0:3}" = "::1" ]
  then
    len=$(expr length "$line")
    for ((a=0; a<=len-12; a++))
    do
      [ "$(expr substr "$line" $a 13)" = "ip6-localhost" ] && let "secondline=secondline+1"
    done
    for ((a=0; a<=len-11; a++))
    do
      [ "$(expr substr "$line" $a 12)" = "ip6-loopback" ] && let "secondline=secondline+1"
    done
    for ((a=0; a<=len-9; a++))
    do
      [ "$(expr substr "$line" $a 10)" = " localhost" ] && let "secondline=secondline+1"
    done
  fi
done < /etc/hosts

  [ "$firstline" = "0" ] && sudo sh -c "echo '127.0.0.1 localhost' >> /etc/hosts"
  [ "$secondline" -lt "3" ] && sudo sh -c "echo '::1 ip6-localhost ip6-loopback localhost' >> /etc/hosts"
