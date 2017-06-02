#!/bin/bash


while read line; do
  echo ${line:0:4}
  len=${#line}
  if [ "${line:0:4}" = "auto" ]
  then
    inter="${line:5}"
    echo "--"
    break
  fi
done < /etc/network/interfaces

echo $inter

