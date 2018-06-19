#!/bin/bash 
#by zhuhaiyan 20130629, for linux datacard CM installation.
#ROOT=./kernel

#check app installation
if [ -f $ROOT/etc/cm.version ]; then
	echo "the CM has beed installed:"
	echo "------------------------------------------"
	cat $ROOT/etc/cm.version
	echo "------------------------------------------"
	echo "please uninstall it firstly, and try again!"
	exit 0    
fi

	#check app is ok
if [ ! -f ./linux/etc/cm.version ]; then
	echo "cm.version is missing! exit."
	exit 0
fi

if [ ! -f ./linux/etc/device.conf ]; then
	echo "device.conf is missing! exit."
	exit 0
fi
	#end

cat ./linux/etc/cm.version
echo -n "continue to install(yes/no)?[yes]"
read INSALL_CONTINUE
if [ "$INSALL_CONTINUE" = "" -o "$INSALL_CONTINUE" = "yes" -o "$INSALL_CONTINUE" = "no" ]; then
	if [ "$INSALL_CONTINUE" = "" ]; then
		INSALL_CONTINUE="yes"
	fi
else
	echo "invalid choice($INSALL_CONTINUE)! exit."
	exit 0
fi
if [ "$INSALL_CONTINUE" = "no" ]; then
	echo "cancel installation!"
	exit 0
fi
#end

echo "get device info..."
MASSSTORAGE_VENDOR=$(echo `grep DefaultVendor ./linux/etc/device.conf | awk -F= '{print $2}'`)
MASSSTORAGE_PRODUCT=$(echo `grep DefaultProduct ./linux/etc/device.conf | awk -F= '{print $2}'`)
VENDOR=$(echo `grep TargetVendor ./linux/etc/device.conf | awk -F= '{print $2}'`)
PRODUCT=$(echo `grep TargetProduct ./linux/etc/device.conf | awk -F= '{print $2}'`)

MASSSTORAGE_VENDOR_STR=$(echo $MASSSTORAGE_VENDOR | grep -i "0x")
if [ "$MASSSTORAGE_VENDOR_STR" != "" ]; then
    MASSSTORAGE_VENDOR=$(expr substr $MASSSTORAGE_VENDOR_STR 3 4)
fi

MASSSTORAGE_PRODUCT_STR=$(echo $MASSSTORAGE_PRODUCT | grep -i "0x")
if [ "$MASSSTORAGE_PRODUCT_STR" != "" ]; then
    MASSSTORAGE_PRODUCT=$(expr substr $MASSSTORAGE_PRODUCT_STR 3 4)
fi

VENDOR_STR=$(echo $VENDOR | grep -i "0x")
if [ "$VENDOR_STR" != "" ]; then
    VENDOR=$(expr substr $VENDOR_STR 3 4)
fi

PRODUCT_STR=$(echo $PRODUCT | grep -i "0x")
if [ "$PRODUCT_STR" != "" ]; then
    PRODUCT=$(expr substr $PRODUCT_STR 3 4)
fi

echo Mass Storage Vendor=0x$MASSSTORAGE_VENDOR
echo Mass Storage Product=0x$MASSSTORAGE_PRODUCT
echo Vendor=0x$VENDOR
echo Product=0x$PRODUCT

#check system is linux 
if [ ! -f $ROOT/etc/issue ]; then
	echo "Unknown linux release version. exit."
	exit 0
fi

echo "check os support..."
if [ "$(cat $ROOT/etc/issue | grep Ubuntu)" != "" -a "$(cat $ROOT/etc/issue | grep 9.04)" != "" ]; then
	echo "Ubuntu 9.04 not support! exit."
	exit 0
fi
if [ "$(cat $ROOT/etc/issue | grep Fedora)" != "" -a "$(cat $ROOT/etc/issue | grep 11)" != "" ]; then
	echo "Fedora 11 not support! exit."
	exit 0
fi
if [ "$(cat $ROOT/etc/issue | grep Fedora)" != "" -a "$(cat $ROOT/etc/issue | grep 12)" != "" ]; then
	echo "Fedora 12 not support! exit."
	exit 0
fi
if [ "$(cat $ROOT/etc/issue | grep Fedora)" = "" -a "$(cat $ROOT/etc/issue | grep Ubuntu)" = "" -a "$(cat $ROOT/etc/issue | grep Mandriva)" = "" ]; then
	echo "The linux release version not support! exit."
	exit 0
fi
echo -n "Linux release version:"
cat $ROOT/etc/issue
echo "[OK]"

#check usbserial driver or modprobe usbserial
echo -n "check driver support..."
if [ "$(cat $ROOT/proc/tty/drivers | grep usbserial)" = "" ]; then
	if [ ! -f $ROOT/lib/modules/$(uname -r)/kernel/drivers/usb/serial/usbserial.ko ]; then
		if [ ! -f $ROOT/lib/modules/$(uname -r)/kernel/drivers/usb/serial/usbserial.ko.gz ]; then
			echo "the usbserial driver not exist. exit."
			exit 0
		fi
	fi
	echo "load usbserial driver..."
	if [ -f $ROOT/lib/modules/$(uname -r)/kernel/drivers/usb/serial/usbserial.ko ]; then
		insmod $ROOT/lib/modules/$(uname -r)/kernel/drivers/usb/serial/usbserial.ko
	else
		modprobe usbserial
	fi
fi
if [ "$(cat $ROOT/proc/tty/drivers | grep usbserial)" = "" ]; then
    echo "the usbserial driver has been not loaded. exit."
    exit 0
fi
echo "[OK]"

echo -n "install usb serial driver..."
OS_REBOOT=0
if [ "$(lsmod | grep usbserial)" = "" ]; then
	MAGIC_ID=$(echo `grep MagicId ./linux/etc/device.conf | awk -F= '{print $2}'`)
	#back up grub.cfg
	if [ -f $ROOT/boot/grub2/grub.cfg.bak.$MAGIC_ID ]; then
		if [ ! -f $ROOT/boot/grub2/grub.cfg.org.$MAGIC_ID ]; then
			echo "ERROR: $ROOT/boot/grub2/grub.cfg.org.$MAGIC_ID is missing!! exit."
			exit 0      
		fi
	else
		cp $ROOT/boot/grub2/grub.cfg $ROOT/boot/grub2/grub.cfg.bak.$MAGIC_ID
		# this is back up of orignal grub.cfg
		if [ ! -f $ROOT/boot/grub2/grub.cfg.org.$MAGIC_ID ]; then
			cp $ROOT/boot/grub2/grub.cfg $ROOT/boot/grub2/grub.cfg.org.$MAGIC_ID
		fi
		sed -i "/linux\t/s/$/ usbserial.vendor=0x$VENDOR usbserial.product=0x$PRODUCT/" $ROOT/boot/grub2/grub.cfg   
		OS_REBOOT=1
	fi
else
	modprobe -r usbserial
	modprobe usbserial vendor=0x$VENDOR product=0x$PRODUCT
fi
echo "[OK]"

AUTORUN="0"
AUTORUN=$(echo `grep AutoRun ./linux/etc/device.conf | awk -F= '{print $2}'`)
if [ "$AUTORUN" != "0" ]; then
    AUTORUN="1"
fi

#add by guleijun for Qualcomm NDIS 2014-12-9
CONFIG=$(echo `grep Platform ./linux/etc/cm.version | awk -F= '{print $2}'`)
echo $CONFIG>/tmp/BMConfig
#end by guleijun

if [ "$(cat $ROOT/etc/issue | grep Ubuntu)" != "" -a "$(cat $ROOT/etc/issue | grep 09.10)" != "" ]; then
	CONFIG=""
fi

if [ "$(cat $ROOT/etc/issue | grep Ubuntu)" != "" -a "$(cat $ROOT/etc/issue | grep 10.04)" != "" ]; then
	CONFIG=""
fi

if [ "$(cat $ROOT/etc/issue | grep Ubuntu)" != "" -a "$(cat $ROOT/etc/issue | grep 10.10)" != "" ]; then
	CONFIG=""
fi

if [ "$(cat $ROOT/etc/issue | grep Ubuntu)" != "" -a "$(cat $ROOT/etc/issue | grep 11.04)" != "" ]; then
	CONFIG=""
fi

if [ "$(cat $ROOT/etc/issue | grep Fedora)" != "" ]; then
	CONFIG=""
fi

if [ "$(cat $ROOT/etc/issue | grep Mandriva)" != "" ]; then
	CONFIG=""
fi

if [ "$CONFIG" = "" ]; then
	CONFIG=$(echo `grep Model ./linux/etc/cm.version | awk -F= '{print $2}'`)
fi

#add by guleijun for Qualcomm NDIS 2014-12-9
SUPPORT=$(echo `grep Support ./linux/etc/cm.version | awk -F= '{print $2}'`)
VERSION=$(echo `grep VERSION ./linux/etc/cm.version | awk -F= '{print $2}'`)
echo $SUPPORT>>/tmp/BMConfig
#end by guleijun

if [ "$SUPPORT" = "MUSYS" ]; then
	CONFIG=$SUPPORT
fi

#add by guleijun 2014-12-9
#cp NDIS driver to linux
if [ "$CONFIG" = "BMQ" ]; then
	cd ./linux/drivers/
	make
	sleep 10
	make install
	sleep 10
	cd ..
	cd ..
fi
#end by guleijun

#create udev rules file.
echo -n "udev rules file..."
EJECT_SCRIPT="./linux/usr/bin/eject.sh"
echo "#!/bin/sh" > $EJECT_SCRIPT
echo "#the file is created automatically, PLEASE DO NOT MODIFY IT!!!" >> $EJECT_SCRIPT
echo "export PATH=\"$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin\"" >> $EJECT_SCRIPT
if [ "$CONFIG" = "BMQ" ];then
	if [ -f $ROOT/lib/modules/$(uname -r)/kernel/drivers/net/usb/GobiNet.ko ];then
               	echo 'rm -rf /tmp/judgement' >> $EJECT_SCRIPT
		echo 'rmmod /lib/modules/$(uname -r)/kernel/drivers/net/usb/GobiNet.ko' >> $EJECT_SCRIPT
		echo 'rmmod usbserial' >> $EJECT_SCRIPT
		echo 'sudo eject /dev/$1' >> $EJECT_SCRIPT
		echo 'insmod /lib/modules/$(uname -r)/kernel/drivers/net/usb/GobiNet.ko' >> $EJECT_SCRIPT
	else
                echo 'rm -rf /tmp/judgement' >> $EJECT_SCRIPT
		echo 'eject /dev/$1' >> $EJECT_SCRIPT
		echo "rmmod usbserial" >> $EJECT_SCRIPT
		#echo "modprobe usbserial vendor=0x$VENDOR product=0x$PRODUCT" >> $EJECT_SCRIPT
		echo "insmod /lib/modules/$(uname -r)/kernel/drivers/usb/serial/usbserial.ko vendor=0x$VENDOR product=0x$PRODUCT" >> $EJECT_SCRIPT
	fi
	chmod +x $EJECT_SCRIPT
	MODEMSWITCH_RULES="./linux/lib/udev/rules.d/20-modemswitch-3g.rules"
	echo "#the file is created automatically, PLEASE DO NOT MODIFY IT!!!" > $MODEMSWITCH_RULES
	if [ "$(cat $ROOT/etc/issue | grep Fedora)" != "" ]; then
		echo "KERNEL==\"sr*\",ACTION==\"add\",ATTRS{idVendor}==\"$MASSSTORAGE_VENDOR\",ATTRS{idProduct}==\"$MASSSTORAGE_PRODUCT\",RUN+=\"/usr/bin/eject.sh %k\""  >> $MODEMSWITCH_RULES
	else
		echo "KERNEL==\"sr*\",ACTION==\"add\",ATTRS{idVendor}==\"$MASSSTORAGE_VENDOR\",ATTRS{idProduct}==\"$MASSSTORAGE_PRODUCT\",RUN+=\"/usr/bin/eject.sh %k\""  >> $MODEMSWITCH_RULES
	fi
elif [ "$CONFIG" = "D600" ] || [ "$CONFIG" = "D610" ] || [ "$CONFIG" = "D620" ]; then
        echo 'rm -rf /tmp/judgement' >> $EJECT_SCRIPT
	echo 'eject /dev/$1' >> $EJECT_SCRIPT
	echo "rmmod usbserial" >> $EJECT_SCRIPT
	#echo "modprobe usbserial vendor=0x$VENDOR product=0x$PRODUCT" >> $EJECT_SCRIPT
	echo "insmod /lib/modules/$(uname -r)/kernel/drivers/usb/serial/usbserial.ko vendor=0x$VENDOR product=0x$PRODUCT" >> $EJECT_SCRIPT
	chmod +x $EJECT_SCRIPT
	MODEMSWITCH_RULES="./linux/lib/udev/rules.d/20-modemswitch-3g.rules"
	echo "#the file is created automatically, PLEASE DO NOT MODIFY IT!!!" > $MODEMSWITCH_RULES
	if [ "$(cat $ROOT/etc/issue | grep Fedora)" != "" ]; then
		echo "KERNEL==\"sr*\",ACTION==\"add\",ATTRS{idVendor}==\"$MASSSTORAGE_VENDOR\",ATTRS{idProduct}==\"$MASSSTORAGE_PRODUCT\",RUN+=\"/usr/bin/eject.sh %k\""  >> $MODEMSWITCH_RULES
	else
		echo "KERNEL==\"sr*\",ACTION==\"add\",ATTRS{idVendor}==\"$MASSSTORAGE_VENDOR\",ATTRS{idProduct}==\"$MASSSTORAGE_PRODUCT\",RUN+=\"/usr/bin/eject.sh %k\""  >> $MODEMSWITCH_RULES
	fi
else
        echo 'rm -rf /tmp/judgement' >> $EJECT_SCRIPT
	echo "modprobe -r usbserial" >> $EJECT_SCRIPT
	echo "modprobe usbserial vendor=0x$VENDOR product=0x$PRODUCT" >> $EJECT_SCRIPT
	echo 'eject /dev/$1' >> $EJECT_SCRIPT
	chmod +x $EJECT_SCRIPT
	MODEMSWITCH_RULES="./linux/lib/udev/rules.d/20-modemswitch-3g.rules"
	echo "#the file is created automatically, PLEASE DO NOT MODIFY IT!!!" > $MODEMSWITCH_RULES
	echo "KERNEL==\"sr*\",ACTION==\"add\",ATTRS{idVendor}==\"$MASSSTORAGE_VENDOR\",ATTRS{idProduct}==\"$MASSSTORAGE_PRODUCT\",RUN+=\"/usr/bin/eject.sh %k\""  >> $MODEMSWITCH_RULES
fi
if [ "$AUTORUN" = "1" ]; then
	if [ "$CONFIG" = "BMQ" ];then
		if [ -f $ROOT/lib/modules/$(uname -r)/kernel/drivers/net/usb/GobiNet.ko ];then
			echo "KERNEL==\"qcqmi1*\",ACTION==\"add\",ATTRS{idVendor}==\"$VENDOR\",ATTRS{idProduct}==\"$PRODUCT\",RUN+=\"/usr/bin/3g_connect.sh ttyUSB1\"" >> $MODEMSWITCH_RULES
		else
			echo "KERNEL==\"ttyACM1|ttyUSB1\",ACTION==\"add\",ATTRS{idVendor}==\"$VENDOR\",ATTRS{idProduct}==\"$PRODUCT\",RUN+=\"/usr/bin/3g_connect.sh %k\"" >> $MODEMSWITCH_RULES
		fi  
	elif [ "$CONFIG" = "D600" ] || [ "$CONFIG" = "D610" ]|| [ "$CONFIG" = "D620" ]; then
		echo "KERNEL==\"ttyACM1|ttyUSB1\",ACTION==\"add\",ATTRS{idVendor}==\"$VENDOR\",ATTRS{idProduct}==\"$PRODUCT\",RUN+=\"/usr/bin/3g_connect.sh %k\"" >> $MODEMSWITCH_RULES
	elif [ "$CONFIG" = "MUSYS" ];then
                        echo "KERNEL==\"ttyACM1|ttyUSB2\",ACTION==\"add\",ATTRS{idVendor}==\"$VENDOR\",ATTRS{idProduct}==\"$PRODUCT\",RUN+=\"/usr/bin/3g_connect.sh %k\"" >> $MODEMSWITCH_RULES     
        else
            	if [ "$VERSION" = "579" ] ;then
			echo "KERNEL==\"ttyACM0|ttyUSB1\",ACTION==\"add\",ATTRS{idVendor}==\"$VENDOR\",ATTRS{idProduct}==\"$PRODUCT\",RUN+=\"/usr/bin/3g_connect.sh %k\"" >> $MODEMSWITCH_RULES
		else
			echo "KERNEL==\"ttyACM0|ttyUSB0\",ACTION==\"add\",ATTRS{idVendor}==\"$VENDOR\",ATTRS{idProduct}==\"$PRODUCT\",RUN+=\"/usr/bin/3g_connect.sh %k\"" >> $MODEMSWITCH_RULES
		fi	
	fi
fi
cp $MODEMSWITCH_RULES $ROOT/lib/udev/rules.d/20-modemswitch-3g.rules
echo "[OK]"

echo -n "ppp config..."
cp -r ./linux/etc/ppp $ROOT/etc/
echo "[OK]"

echo -n "APN and dial script..."
if [ ! -d $ROOT/etc/3g_modem_connection ]; then
	mkdir -p $ROOT/etc/3g_modem_connection
fi
cp -r ./linux/etc/3g_modem_connection $ROOT/etc/
echo "[OK]"

echo -n "main app..."
SYSTEM_BIT=$($(which getconf) LONG_BIT)
if [ "$SYSTEM_BIT" = "64" ]; then
	chmod +x ./linux/usr/bin/x64/*
	cp ./linux/usr/bin/x64/* $ROOT/usr/bin 
else
	chmod +x ./linux/usr/bin/x86/*
	cp ./linux/usr/bin/x86/* $ROOT/usr/bin
fi
chmod +x ./linux/usr/bin/*.sh 
cp ./linux/usr/bin/*.sh $ROOT/usr/bin
echo "[OK]"

#kill system ModemManager
if [ -f /usr/share/dbus-1/system-services/org.freedesktop.ModemManager.service ]; then
	mv /usr/share/dbus-1/system-services/org.freedesktop.ModemManager.service /usr/share/dbus-1/system-services/org.freedesktop.ModemManager.service.disabled
	OS_REBOOT=1
	echo -n "disable modem-manager service..."
	echo "[OK]"
fi

if [ -f /usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service ]; then
	mv /usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service /usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service.disabled
	OS_REBOOT=1
	echo -n "disable modem-manager service..."
	echo "[OK]"
fi

#kill system modem-manager
if [ -f /usr/sbin/modem-manager ]; then
	mv /usr/sbin/modem-manager /usr/sbin/modem-manager.disabled
	OS_REBOOT=1
	echo -n "disable modem-manager service..."
	echo "[OK]"
fi

if [ -f /usr/sbin/ModemManager ]; then
	mv /usr/sbin/ModemManager /usr/sbin/ModemManager.disabled
	OS_REBOOT=1
	echo -n "disable modem-manager service..."
	echo "[OK]"
fi

#cp cm.version to linux
cp ./linux/etc/device.conf $ROOT/etc/device.conf
cp ./uninstall.sh $ROOT/usr/bin/3g_modem_connect_uninstall.sh
cp ./linux/etc/cm.version $ROOT/etc/cm.version

echo Installation Done!!
echo "---------------------------"
cat $ROOT/etc/cm.version
echo "---------------------------"

#add by guleijun for Qualcomm NDIS
if [ $CONFIG = "BMQ" ];then
            OS_REBOOT=1
fi
#end
if [ "$OS_REBOOT" = "1" ]; then
	echo -n "os need reboot now(yes/no)?[yes]"
	read OS_REBOOT_REQUIRE
	if [ "$OS_REBOOT_REQUIRE" = "" -o "$OS_REBOOT_REQUIRE" = "yes" -o "$OS_REBOOT_REQUIRE" = "no" ]; then
		if [ "$OS_REBOOT_REQUIRE" = "" ]; then
	    	OS_REBOOT_REQUIRE="yes"
		fi
    	else
		echo "invalid choice($OS_REBOOT_REQUIRE)! exit."
		exit 0
    	fi
	if [ "$OS_REBOOT_REQUIRE" = "yes" ]; then
		reboot
	fi
fi
