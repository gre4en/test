#!/bin/bash


sudo cp -f /etc/hosts tmp.txt
sudo rm -f /etc/hosts
sudo touch /etc/hosts
while read line; do
  [ "${line:0:9}" != "127.0.0.1" ] && [ "${line:0:3}" != "::1" ] && sudo sh -c "echo '$line' >> /etc/hosts"
done < tmp.txt
sudo sh -c "echo '127.0.0.1 localhost' >> /etc/hosts"
sudo sh -c "echo '::1 ip6-localhost ip6-loopback localhost' >> /etc/hosts"

