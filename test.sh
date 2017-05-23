#!/bin/bash

IP=$(netstat -r | grep 'default' | cut -d: -f2 | awk '{ print $2}') 
echo "$IP"
