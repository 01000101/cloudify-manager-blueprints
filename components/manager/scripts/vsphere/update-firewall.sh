#!/bin/bash -e

uname -a

status=`systemctl status firewalld | grep "Active:"| awk '{print $2}'`

if [ "z$status" == 'zactive' ]; then
    # add http(s) rules
    sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
    sudo firewall-cmd --zone=public --add-port=443/tcp --permanent
    # add influxdb connection
    sudo firewall-cmd --zone=public --add-port=8086/tcp --permanent
    # port for agent download
    sudo firewall-cmd --zone=public --add-port=53229/tcp --permanent
    # port for internal rest
    sudo firewall-cmd --zone=public --add-port=53333/tcp --permanent
    # port for AQMP
    sudo firewall-cmd --zone=public --add-port=5672/tcp --permanent
    # port for diamond
    sudo firewall-cmd --zone=public --add-port=8100/tcp --permanent

    sudo firewall-cmd --reload

else
    echo "Skipping update firewall, please update rules manually"
fi