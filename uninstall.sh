
#by zhuhaiyan 20130629, for linux datacard CM uninstallation.
#ROOT=./kernel

killall pppd

if [ ! -f $ROOT/etc/cm.version ]; then
    echo "the CM is not found."
    exit 0    
fi

echo "the CM has beed installed:"
echo "------------------------------------------"
cat $ROOT/etc/cm.version
echo "------------------------------------------"
echo -n "continue to uninstall(yes/no)?[yes]"
read UNINSALL_CONTINUE

if [ "$UNINSALL_CONTINUE" = "" -o "$UNINSALL_CONTINUE" = "yes" -o "$UNINSALL_CONTINUE" = "no" ]; then
    if [ "$UNINSALL_CONTINUE" = "" ]; then
        UNINSALL_CONTINUE="yes"
    fi
else
    echo "invalid choice($UNINSALL_CONTINUE)! exit."
    exit 0
fi


if [ "$UNINSALL_CONTINUE" = "no" ]; then
    echo "cancel uninstallation!"
    exit 0
fi   


echo -n "uninstall driver..."
DRIVER_UNINSTALL="[OK]"
OS_REBOOT=0
if [ "$(cat $ROOT/proc/tty/drivers | grep usbserial)" != "" ]; then
    if [ -f $ROOT/lib/modules/$(uname -r)/kernel/drivers/usb/serial/usbserial.ko ]; then
        modprobe -r usbserial
    else
        MAGIC_ID=$(echo `grep MagicId $ROOT/etc/device.conf | awk -F= '{print $2}'`)
        if [ -f $ROOT/boot/grub2/grub.cfg.org.$MAGIC_ID ]; then
            cp $ROOT/boot/grub2/grub.cfg.org.$MAGIC_ID $ROOT/boot/grub2/grub.cfg
            OS_REBOOT=1
        else
           if [ -f $ROOT/boot/grub2/grub.cfg.bak.$MAGIC_ID ]; then
               cp $ROOT/boot/grub2/grub.cfg.bak.$MAGIC_ID $ROOT/boot/grub2/grub.cfg
               OS_REBOOT=1
           else
               DRIVER_UNINSTALL="[FAIL]"
           fi
        fi
    fi
fi

echo "$DRIVER_UNINSTALL"
if [ "$DRIVER_UNINSTALL" = "[FAIL]" ]; then
    echo "!!!!grub.cfg backup is missing!!!"
    echo "$ROOT/boot/grub2/grub.cfg can not be resotred!"  
else
    rm $ROOT/boot/grub2/grub.cfg.bak.$MAGIC_ID  
    #rm $ROOT/boot/grub2/grub.cfg.org.$MAGIC_ID     
fi

echo -n "uninstall rules file..."
if [ -f $ROOT/lib/udev/rules.d/20-modemswitch-3g.rules ]; then
    rm $ROOT/lib/udev/rules.d/20-modemswitch-3g.rules
fi
echo "[OK]"

echo -n "uninstall ppp config..."
if [ -f $ROOT/etc/ppp/chap-secrets.template ]; then
  rm $ROOT/etc/ppp/chap-secrets.template
fi
if [ -f $ROOT/etc/ppp/pap-secrets.template ]; then
  rm $ROOT/etc/ppp/pap-secrets.template
fi
if [ -f $ROOT/etc/ppp/ip-down.local ]; then
  rm $ROOT/etc/ppp/ip-down.local
fi
if [ -f $ROOT/etc/ppp/peers/3g.template ]; then
  rm $ROOT/etc/ppp/peers/3g.template
fi
echo "[OK]"

echo -n "uninstall APN and dial script..."
if [ -d $ROOT/etc/3g_modem_connection ]; then
   rm -r $ROOT/etc/3g_modem_connection
fi
echo "[OK]"

echo -n "uninstall main app..."
if [ -f $ROOT/usr/bin/3g_connect.sh ]; then
  rm $ROOT/usr/bin/3g_connect.sh
fi
if [ -f $ROOT/usr/bin/3g_connect_proc.sh ]; then
  rm $ROOT/usr/bin/3g_connect_proc.sh
fi
if [ -f $ROOT/usr/bin/connect.sh ]; then
  rm $ROOT/usr/bin/connect.sh
fi
if [ -f $ROOT/usr/bin/atinit ]; then
  rm $ROOT/usr/bin/atinit
fi

if [ -f $ROOT/usr/bin/salestracking ]; then
  rm $ROOT/usr/bin/salestracking
fi

if [ -f $ROOT/usr/bin/salestracking.sh ]; then
  rm $ROOT/usr/bin/salestracking.sh
fi

if [ -f $ROOT/usr/bin/modemtoatmode ]; then
  rm $ROOT/usr/bin/modemtoatmode
fi
if [ -f $ROOT/usr/bin/eject.sh ]; then
  rm $ROOT/usr/bin/eject.sh
  echo "rm eject"
fi
#Delet install
if [ -f $ROOT/home/install.sh ];then
  rm -fr $ROOT/home/install.sh
  echo "rm install"
fi
#Delet uninstall 
if [ -f $ROOT/home/uninstall.sh ];then
  rm -fr $ROOT/home/uninstall.sh
  echo "rm uninstall"
fi
#Delet package
if [ -f $ROOT/home/*.tar.gz ];then
  rm -fr $ROOT/home/*.tar.gz
  echo "rm *.tar.gz"
fi
#Delet ndis drivers
if [ -f $ROOT/lib/modules/$(uname -r)/kernel/drivers/net/usb/GobiNet.ko ] ; then
  rm -fr /lib/modules/$(uname -r)/kernel/drivers/net/usb/GobiNet.ko
  echo "rm ndis dirvers"
fi
#Delet linux files
rm -fr $ROOT/home/linux
echo "rm linux floder"
echo "[OK]"

if [ -f /usr/share/dbus-1/system-services/org.freedesktop.ModemManager.service.disabled ]; then
    mv /usr/share/dbus-1/system-services/org.freedesktop.ModemManager.service.disabled /usr/share/dbus-1/system-services/org.freedesktop.ModemManager.service
echo -n "restore modem-manager service..."
fi
if [ -f /usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service.disabled ]; then
    mv /usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service.disabled /usr/share/dbus-1/system-services/org.freedesktop.ModemManager1.service
echo -n "restore modem-manager service..."
fi
echo "[OK]"
if [ -f /usr/sbin/modem-manager.disabled ]; then
    mv /usr/sbin/modem-manager.disabled /usr/sbin/modem-manager
echo -n "restore modem-manager service..."
fi
if [ -f /usr/sbin/ModemManager.disabled ]; then
    mv /usr/sbin/ModemManager.disabled /usr/sbin/ModemManager
echo -n "restore modem-manager service..."
fi
echo "[OK]"

echo "Unintallation Done!!"
echo "------------------------------"
cat $ROOT/etc/cm.version
rm $ROOT/etc/cm.version
echo "------------------------------"

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

#done!!!






