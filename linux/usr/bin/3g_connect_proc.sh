#!/bin/bash
#by zhuhaiyan 20120712
export PATH="$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

# check device
if [ "$1" = "" ]; then
	echo "device is null. exit 1."
	exit 1
fi

dev_str=`echo $1 | grep "tty"`
if [ "$dev_str" = "" ]; then
	echo "$1 is a invalid device! exit 1."
	exit 1
fi

dev_str=`ls /dev/tty* | grep "$1"`
if [ "$dev_str" = "" ]; then
	echo "$1 is not exist! exit 1."
	exit 1
fi

# check ppp0
ppp0_str=`ifconfig | grep "ppp0"`
if [ "$ppp0_str" != "" ]; then
	echo "ppp0 is exist! exit 0"
	exit 0
fi

# init comm port.
atinit /dev/ttyUSB0
atinit /dev/ttyUSB1
atinit /dev/ttyUSB2

# unlock device lock.
if [ -f /usr/bin/deviceunlock.sh ]; then
	/usr/bin/deviceunlock.sh $1
fi

tries=0
string_OK=""
while [ $tries -le 3 -a "$string_OK" = "" ]; do
#===================================do=================
	atcmd /dev/$1 "AT+CFUN=1" > /tmp/cfun
	string_OK=`grep "OK" /tmp/cfun`
	tries=$((tries + 1))
#=================================done=================
done

if [ "$string_OK" = "" ]; then
	echo fail to execute at+cfun=1
	exit 1
fi
#echo successfull to trun on radio.
# read all data form device.
echo "clear rx buffer form /dev/$1..."
`cat /dev/$1 > /tmp/atrxbuff & sleep 3` 1>/dev/null 2>&1
killall cat
sleep 5
echo "check sim pin status..."
atcmd /dev/$1 "AT+CPIN?" > /tmp/cpin
AT_RETURN=`grep "READY" /tmp/cpin`
if [ "$AT_RETURN" = "" ]; then
    echo "Invalid SIM card, please check sim pin status."
    exit 1
fi
echo "SIM is ready!!"

#for auto find apn and connect to internet.

#get apn profile

tries=0
string_plmn=""

while [ $tries -le 3 -a "$string_plmn" = "" ]; do
#============================do======================
echo get plmn by +bmhplmn tries=$tries
atcmd /dev/$1 "AT+BMHPLMN" > /tmp/bmhplmn
AT_RETURN=`grep "+BMHPLMN:" /tmp/bmhplmn`
#by zhuhaiyan 20130402 --- get plmn
echo $AT_RETURN | awk '{print $2}' > /tmp/plmn

if [ "$AT_RETURN" != "" ]; then
    
    string_plmn=`echo $AT_RETURN | awk '{print $2}'`
    if [ "$string_plmn" = "" ]; then
        tries=$((tries + 1))
        continue
    fi
    
    string_plmn=`expr substr $string_plmn 1 5`
    break
fi

tries=$((tries + 1))
#==================================done==========
done

tries=0

while [ $tries -le 3 -a "$string_plmn" = "" ]; do
#=============================do=======================

if [ "$string_plmn" = "" ]; then
    echo get imsi by +cimi tries=$tries
    atcmd /dev/$1 "AT+CIMI" > /tmp/cimi
    AT_RETURN=`grep "[0-9]" /tmp/cimi`
    if [ "$AT_RETURN" = "" ]; then
        echo invalid imsi. 
        tries=$((tries + 1))
        continue
    fi
    string_cimi=`echo $AT_RETURN | awk '{print $1}'`
    if [ "$string_cimi" = "" ]; then
        echo fail to get cimi.
        tries=$((tries + 1))
        continue
    fi
    #get 5 num for plmn form imsi.
    string_plmn=`expr substr $string_cimi 1 5`
    
fi
#=========================done===================
done

if [ "$string_plmn" = "" ]; then
    echo "fail to get PLMN."
    exit 1
fi

#echo success to get PLMN=$string_plmn

#echo "start to wait for register network..."

tries=0
string_RegHome=""
string_RegRoaming=""
string_Reg="0"

while [ $tries -le 45 -a "$string_Reg" = "0" ]; do
#===================================do=================
echo "wait for network registered...,tries=$tries"
sleep 1
atcmd /dev/$1 "AT+CREG?" > /tmp/cgatt

string_RegHome=`grep ",1" /tmp/cgatt`
string_RegRoaming=`grep ",5" /tmp/cgatt`
if [ "$string_RegHome" != "" -o "$string_RegRoaming" != "" ]; then
    string_Reg="1"
fi

tries=$((tries + 1))
#=================================done=================
done

if [ "$string_Reg" = "0" ]; then
    echo "fail to register network, please check."
    exit 1
fi

echo "successfull to register network."

#by zhuhaiyan 20130402 -- get cellid and lac

tries=0
strlac=""
strcellid=""
stridok="0"

while [ $tries -le 10 -a "$stridok" = "0" ]; do
#==================================================
atcmd /dev/$1 "AT+CREG=2" > /tmp/creg
atcmd /dev/$1 "AT+CREG?" > /tmp/creg
strlac=`grep "+CREG:" /tmp/creg | awk '{print $2}' | awk -F, '{print $3}'`
strcellid=`grep "+CREG:" /tmp/creg | awk '{print $2}' | awk -F, '{print $4}'`
if [ "$strlac" != "" -a "$strcellid" != "" ]; then
    stridok="1"
fi
tries=$((tries + 1))
#=====================done=========================
done

if [ "$stridok" = "1" ]; then
    echo $strlac > /tmp/lac
    echo $strcellid > /tmp/cellid
else
    echo "fail to geti lac and cell id."
    exit 1
fi


atcmd /dev/$1 "AT+CREG=0" > /tmp/creg
sleep 1
#by zhuhaiyan 20130402 -- get imei
tries=0
strimei=""

while [ $tries -le 10 -a "$strimei" = "" ]; do
#========================================================
atcmd /dev/$1 "AT+CGSN" > /tmp/cgsn
strimei=`sed -n "2p" /tmp/cgsn`
if [ "$strimei" = "" ]; then
    strimei=`sed -n "3p" /tmp/cgsn`
fi
tries=$((tries + 1))
#==================done==================================
done

if [ "$strimei" != "" ]; then
    echo $strimei > /tmp/imei
else
    echo "fail to get imei."
    exit 1
fi

atcmd /dev/$1 "AT+CGMR" > /tmp/cgmr
sleep 1
grep "+CGMR:" /tmp/cgmr | awk '{print $2}' > /tmp/swver

grep Version /etc/cm.version | awk -F= '{print $2}' > /tmp/swver
grep Model /etc/cm.version | awk -F= '{print $2}' > /tmp/model
grep HW /etc/cm.version | awk -F= '{print $2}' > /tmp/hw

#get apn profile
echo string_plmn=$string_plmn
apn_profile=`grep $string_plmn /etc/3g_modem_connection/apn.dat`
echo get apn profile = $apn_profile
apn_dial=`echo $apn_profile | awk -F, '{ print $4 }'`
apn_user=`echo $apn_profile | awk -F, '{ print $5 }'`
apn_pass=`echo $apn_profile | awk -F, '{ print $6 }'`
apn_apn=`echo $apn_profile | awk -F, '{ print $7 }'`
apn_auth=`echo $apn_profile | awk -F, '{ print $8 }'`

if [ "$apn_dial" = "" ]; then
  apn_dial="*99#"
fi

echo apn_dial=$apn_dial
echo apn_user=$apn_user
echo apn_pass=$apn_pass
echo apn_apn=$apn_apn
echo apn_auth=$apn_auth

#add by guleijun 2014-12-11 for Qualcomm NDIS
if [ "$2" != "" ]; then
	SUPPORT_QUAL=$2
fi

tries=0
CONNECTION_DONE=""
AT_RETURN=""

if [ "$(cat $ROOT/etc/issue | grep Ubuntu)" != "" -a "$(cat $ROOT/etc/issue | grep 09.10)" != "" ]; then
	SUPPORT_QUAL=""
fi

if [ "$(cat $ROOT/etc/issue | grep Ubuntu)" != "" -a "$(cat $ROOT/etc/issue | grep 10.04)" != "" ]; then
	SUPPORT_QUAL=""
fi

if [ "$(cat $ROOT/etc/issue | grep Ubuntu)" != "" -a "$(cat $ROOT/etc/issue | grep 10.10)" != "" ]; then
	SUPPORT_QUAL=""
fi

if [ "$(cat $ROOT/etc/issue | grep Ubuntu)" != "" -a "$(cat $ROOT/etc/issue | grep 11.04)" != "" ]; then
	SUPPORT_QUAL=""
fi

if [ "$(cat $ROOT/etc/issue | grep Fedora)" != "" ]; then
	SUPPORT_QUAL=""
fi

if [ "$(cat $ROOT/etc/issue | grep Mandriva)" != "" ]; then
	SUPPORT_QUAL=""
fi

if [ -f $ROOT/lib/modules/$(uname -r)/kernel/drivers/net/usb/GobiNet.ko ];then
	echo "find ndis drivers"
else
	echo "not support ndis"
	SUPPORT_QUAL=""
fi
FLAG=`grep VIVO /etc/cm.version | awk -F '=' '{print $2}'`
if [ "$SUPPORT_QUAL" = "BMQ" ]; then
	echo "start connection by NDIS";
	while [ $tries -le 3 -a "$CONNECTION_DONE" = "" ]; do
		dev_str=`ls /dev/$1`
	    	if [ "$dev_str" = "" ]; then
			echo "$1 is missing. exit"
			rm -rf /tmp/*
			exit 0
	   	fi

		#frist disconnect
		AT_RETURN=""
		atcmd /dev/$1 "AT\$QCRMCALL=0,1" > /tmp/QCRMCALLDIS
		sleep 1

		tryTimes=0	
		while [ $tryTimes -le 5 -a "$AT_RETURN" = "" ]; do
			sleep 1
			AT_RETURN=`grep "OK" /tmp/QCRMCALLDIS`
			tryTimes=$((tryTimes + 1))
			echo "disconnect stat is " $AT_RETURN
		done

		#send AT when pwd and username not empty
		if [ "$apn_user" != "" -o "$apn_pass" != "" ]; then
			AT_RETURN=""
			atcmd /dev/$1 "AT\$QCPDPP=1,$apn_auth,$apn_pass,$apn_user" > /tmp/QCPDPP
			sleep 1
			tryTimes=0	
			while [ $tryTimes -le 5 -a "$AT_RETURN" = "" ]; do
				sleep 1
				AT_RETURN=`grep "OK" /tmp/QCPDPP`
				tryTimes=$((tryTimes + 1))	
			done
		fi

		#connection
		if [ "$AT_RETURN" != "" ]; then
			echo "try connecting!"
			AT_RETURN=""
                                    if [ $FLAG = "VIVO INTERNET" ]; then
                                            	atcmd /dev/$1 "AT\$QCRMCALL=1,12" > /tmp/QCRMCALLCON 
                                    else
                                                atcmd /dev/$1 "AT\$QCRMCALL=1,1,1,2,1,1,\"$apn_apn\"" > /tmp/QCRMCALLCON
                                    fi
			sleep 10

			PORT_NAME=""
			echo `ls /dev/qcqmi1*` > /tmp/qcqmi
			PORT_NAME=`grep "qcqmi" /tmp/qcqmi`
			PORT_NAME=`echo ${PORT_NAME#*/dev/qcqmi1\*}`
	
			AAA=`(uname -a) | grep 64`
			if ["$AAA" = ""];then
			echo "system is 32"
			else
			echo "system is 64"
			fi
			if [ "$(cat $ROOT/etc/issue | grep Ubuntu)" != "" -a "$(cat $ROOT/etc/issue | grep 13.04)" != "" -a "$AAA" = "" ]; then
			
			ifconfig $PORT_NAME down
			sleep 1
			ifconfig $PORT_NAME up	
			fi
			if [ "$(cat $ROOT/etc/issue | grep Ubuntu)" != "" -a "$(cat $ROOT/etc/issue | grep 13.10)" != "" -a "$AAA" = "" ]; then
			
			ifconfig $PORT_NAME down
			sleep 1
			ifconfig $PORT_NAME up	
			fi
			if [ "$(cat $ROOT/etc/issue | grep Ubuntu)" != "" -a "$(cat $ROOT/etc/issue | grep 14.04)" != "" -a "$AAA" != "" ]; then
			
			ifconfig $PORT_NAME down
			sleep 1
			ifconfig $PORT_NAME up	
			fi
			tryTimes=0	
			while [ $tryTimes -le 30 -a "$AT_RETURN" = "" ]; do
				echo "look for ip address $tryTimes!"

				dev_str=`ls /dev/$1`
	    			if [ "$dev_str" = "" ]; then
					echo "$1 is missing. exit"
					rm -rf /tmp/*
					exit 0
	   			fi
				
				#AT_RETURN=`ifconfig $PORT_NAME`
				#echo $AT_RETURN > /tmp/IFCONFIG

				AT_RETURN=`ifconfig $PORT_NAME | grep addr:`
				echo "ip is " $AT_RETURN
				tryTimes=$((tryTimes + 1))
				sleep 1
			done		
		fi

		dev_str=`ls /dev/$1`
	    	if [ "$dev_str" = "" ]; then
			echo "$1 is missing. exit"
			rm -rf /tmp/*
			exit 0
	   	fi
		
		if [ "$AT_RETURN" != "" ]; then
			CONNECTION_DONE="OK"
		fi

		tries=$((tries + 1))
	done
fi

if [ "$CONNECTION_DONE" != "" ]; then
#	PORT_NAME=""
#	echo `ls /dev/qcqmi1*` > /tmp/qcqmi
#	PORT_NAME=`grep "qcqmi" /tmp/qcqmi`
#	PORT_NAME=`echo ${PORT_NAME#*/dev/qcqmi1\*}`
#	echo $PORT_NAME
	
#	ifconfig $PORT_NAME down
#	ifconfig $PORT_NAME up	
	echo "CONNECTION_DONE is " $CONNECTION_DONE > /tmp/CS
	exit 0
else
	atcmd /dev/$1 "AT\$QCRMCALL=0,1" > /tmp/QCRMCALLDIS
	sleep 1
	#if NDIS failed use pppd
	echo "start pppd"
	#make a chat script
	cp /etc/3g_modem_connection/3g.template /etc/3g_modem_connection/3g
	sed -i "s/__DIAL__/$apn_dial/g" /etc/3g_modem_connection/3g
	if [ "$apn_apn" != "" ]; then
	    sed -i "s/__APN__/$apn_apn/g" /etc/3g_modem_connection/3g
	    sed -i "s/__NO_APN__/OK/g" /etc/3g_modem_connection/3g
	else
	    sed -i "s/__NO_APN__/#/g" /etc/3g_modem_connection/3g
	fi

	#ppp ipv4/v6
	ppp_ipv4v6=`grep ppp_ipv4v6 /etc/device.conf | awk -F= '{print $2}'`
	if [ "$ppp_ipv4v6" = "1" ]; then
	    sed -i "s/\"IP\"/\"IPV4V6\"/g" /etc/3g_modem_connection/3g
	fi


	#make a pppd connection script.
	cp /etc/ppp/peers/3g.template /etc/ppp/peers/3g
	sed -i "s/__DEVICE__/$1/g" /etc/ppp/peers/3g
	sed -i "s/__USER__/$apn_user/g" /etc/ppp/peers/3g
	sed -i "s/__DIAL__/$apn_dial/g" /etc/ppp/peers/3g
	sed -i "s/__APN__/$apn_apn/g" /etc/ppp/peers/3g
	#make pap-secrets
	cp /etc/ppp/pap-secrets.template /etc/ppp/pap-secrets
	sed -i "s/__USER__/$apn_user/g" /etc/ppp/pap-secrets
	sed -i "s/__PASSWORD__/$apn_pass/g" /etc/ppp/pap-secrets
	#make chap-secrets
	cp /etc/ppp/chap-secrets.template /etc/ppp/chap-secrets
	sed -i "s/__USER__/$apn_user/g" /etc/ppp/chap-secrets
	sed -i "s/__PASSWORD__/$apn_pass/g" /etc/ppp/chap-secrets

		tries_pppd_call_3g=0
		ppp0_str=""

		while [ $tries_pppd_call_3g -le 3 -a "$ppp0_str" = "" ]; do 
		#==========================================================
		#connect to internet
		pppd call 3g

		tries=0
		echo "pppd connecting...(timeout=120 seconds)"
		ppp0_str=`ifconfig | grep "ppp0"`

		while [ "$ppp0_str" = "" -a $tries -le 120 ]; do
		    sleep 1
		    echo "pppd connecting...,tries=$tries"
		    ppp0_str=`ifconfig | grep "ppp0"`
		    dev_str=`ls /dev/$1`
		    if [ "$dev_str" = "" ]; then
			echo "$1 is missing. exit"
			killall pppd
			exit 0
		    fi
		    tries=$((tries + 1))
		done

		if [ "$ppp0_str" != "" ]; then
		    #check OS
		    #if [ "$(cat /etc/issue | grep Fedora)" != "" -o "$(cat /etc/issue | grep Mandriva)" != "" ]; then
			if [ -f /etc/resolv.conf ]; then
			      cp /etc/resolv.conf /etc/resolv.conf.bak 
			  fi
			#get DNS
			if [ "$(cat /etc/issue | grep Fedora)" != "" -o "$(cat /etc/issue | grep Mandriva)" != "" ]; then
			    grep -rnw "DNS address" /var/log/messages > /tmp/dns
			else
			    grep -rnw "DNS address" /var/log/syslog > /tmp/dns
			fi	
			lastline=`cat /tmp/dns | wc -l`
			dns2=$(sed -n "$lastline"p /tmp/dns | sed 's/.*DNS address //g')
			dns1=$(sed -n "`expr $lastline - 1`"p /tmp/dns | sed 's/.*DNS address //g')
			echo "get dns1=$dns1, dns2=$dns2"
			if [ "$dns1" != "" -a "$dns2" != "" ]; then
			    echo "nameserver $dns1" > /etc/resolv.conf
			    echo "nameserver $dns2" >> /etc/resolv.conf
			fi
		    #fi
		    
		else
		    killall pppd
		    sleep 1
		    modemtoatmode
		    sleep 2
		fi
		#===========================done============================
		tries_pppd_call_3g=$((tries_pppd_call_3g + 1))

		done
		echo "B" >> /tmp/cpin
		if [ "$ppp0_str" = "" ]; then
		    echo "pppd connection timeout! exit 1."
		    killall -9 pppd
		    exit 1
		else
		    echo "pppd is connected."
		    
		    #sales tracking
		    if [ -f /usr/bin/salestracking.sh ]; then
			/usr/bin/salestracking.sh ttyUSB1 &
		    fi
		fi	
fi
sleep 365d
#end bu guleijun
