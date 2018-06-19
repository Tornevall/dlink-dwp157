#!/bin/sh
#by zhuhaiyan 20130717

#by guleijun for D600 20140120 add for NDIS
if [ -f $ROOT/tmp/judgement ]; then
	exit 0
fi

if [ -f $ROOT/etc/cm.version ]; then
	echo "read config"
	echo "------------------------------------------"
	CONFIG=$(echo `grep Platform $ROOT/etc/cm.version | awk -F= '{print $2}'`)
	echo $CONFIG>>/tmp/BMConfig
	if [ "$CONFIG" = "" ]; then
		CONFIG=$(echo `grep Model $ROOT/etc/cm.version | awk -F= '{print $2}'`)
		echo $CONFIG>/tmp/BMConfig
	fi
	if [ "$CONFIG" = "BMQ" ] || [ "$CONFIG" = "D610" ] || [ "$CONFIG" = "D600" ];then
		echo $CONFIG
		VENDOR=$(echo `grep TargetVendor $ROOT/etc/device.conf | awk -F= '{print $2}'`)
		echo $VENDOR>>/tmp/BMDevice
		PRODUCT=$(echo `grep TargetProduct $ROOT/etc/device.conf | awk -F= '{print $2}'`)
		echo $PRODUCT>>/tmp/BMDevice
		#rmmod usbserial
   		echo "VENDOR"=$VENDOR
    		echo "PRODUCT"=$PRODUCT
    		modprobe usbserial vendor=$VENDOR product=$PRODUCT
	fi
	echo "------------------------------------------"
fi

echo "3g_connect.sh has been done!" > /tmp/judgement
#end by guleijun

3g_connect_proc.sh $1 $CONFIG > /tmp/3g_connect_log

