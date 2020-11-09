#!/bin/bash
# Created by Nemanja

function opensc_conf_file {
	if grep -c "max_send_size = 65535" /etc/opensc/opensc.conf &> /dev/null
	then 
		echo -e "Config file contains proper data."
	else
		echo -e "Editing the config file..."
sudo chmod 666 /etc/opensc/opensc.conf
echo "# The following section shows definitions for PC/SC readers.
reader_driver pcsc {
# Limit command and response sizes. Some Readers don't propagate their
# transceive capabilities correctly. max_send_size and max_recv_size

# allow setting the limits manually, for example to enable extended
# length capabilities.
# Default: max_send_size = 255, max_recv_size = 256;
max_send_size = 65535;
max_recv_size = 65536;" >> /etc/opensc/opensc.conf
sudo chmod 444 /etc/opensc/opensc.conf
	fi
}

function manage {
	program=$1
	mode=$2

	if [ $mode == "R" ]
	then
		echo -e "\nRemoving $program...\n"
		sleep 2
		sudo apt-get remove -y --purge $program
		sudo apt-get autoremove -y
		if [ $program == "icaclient" ] && [ -d "/opt/Citrix" ]
		then
		    echo -e "\nRemoving Citrix folder...\n"
			sudo rm -r /opt/Citrix
		elif [ $program == "opensc" ] && [ -d "/opt/opensc" ]
		then
		    echo -e "\nRemoving opensc folder...\n"
			sudo rm -r /etc/opensc
		fi
	fi
	dpkg -s $program &> /dev/null
	if [ $? -ne 0 ]
	then
		if [ $mode == "R" ]
		then
			echo -e "\nInstalling $program...\n"
			sleep 2
		else
			echo "$program isn't installed. Installing..."  
		fi
		if [ $program == "icaclient" ]
		then
			install_citrix
		else
			sudo apt-get update
			sudo apt-get install -y $program
		fi
	else
		echo "$program is already installed"
	fi
}

function install_citrix {
# https://ubuntuforums.org/showthread.php?t=1481300
# Get arch type of ubuntu
# i686 = 32 bit
# x86_64 = 64 bit

ARCH_TYPE=`uname -m`

if [ $ARCH_TYPE = "i686" ] 
then
  GDA=`curl -sS https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html | awk '/icaclient_/ && /i386/ && /__gda__/' | cut -d? -f2 | cut -d\" -f1`
  STRING=`curl -sS https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html | awk '/icaclient_/ && /i386/ && /filepathOrUrl/'`
  DOWNLOAD_LINK=`grep -Eo 'downloads[^"]+' <<< $STRING`
  DOWNLOAD_LINK=`echo $DOWNLOAD_LINK | xargs`
  DOWNLOAD_LINK="${DOWNLOAD_LINK}?${GDA}"
elif [ $ARCH_TYPE = "x86_64" ] 
then
  GDA=`curl -sS https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html | awk '/icaclient_/ && /amd64/ && /__gda__/' | cut -d? -f2 | cut -d\" -f1`
  STRING=`curl -sS https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html | awk '/icaclient_/ && /amd64/ && /filepathOrUrl/'`
  DOWNLOAD_LINK=`grep -Eo 'downloads[^"]+' <<< $STRING`
  DOWNLOAD_LINK=`echo $DOWNLOAD_LINK | xargs`
  DOWNLOAD_LINK="${DOWNLOAD_LINK}?${GDA}"
fi

filename=$(basename "$DOWNLOAD_LINK" | cut -d? -f1)

cd /tmp
wget -O $filename $DOWNLOAD_LINK

# install (get error on missing dependencies)
sudo dpkg -i $filename

# https://askubuntu.com/questions/40011/how-to-let-dpkg-i-install-dependencies-for-me
# install dependencies
if [ $? -ne 0 ]
then
  echo "[WARNING] Dependencies not satisfied, trying to obtain them and install again"
  sudo apt-get -f install
  sudo dpkg -i $filename
fi

rm /tmp/$filename

echo -e "\nLinking certificates to Citrix.\n"
sudo ln -s /usr/share/ca-certificates/mozilla/* /opt/Citrix/ICAClient/keystore/cacerts/
}

#-----------------------#
# Main part starts here #
#-----------------------#

if [ -z "$1" ]; then
	mode="N"
else
	mode=$1
fi

if [ $mode == "R" ]
then
	echo -e "Reinstalling card...\n"
	echo -e "^C to stop it, or wait."
	sleep 10
fi

manage opensc $mode
manage pcscd $mode
manage libnss3-tools $mode

if [ $mode == "R" ] && [ -d "$HOME/.pki/nssdb" ]
then
	echo -e "\nRemoving nssdb folder..."
	rm -r $HOME/.pki/nssdb
fi

if [ ! -d "$HOME/.pki/nssdb" ] && echo -e "\nDirectory $HOME/.pki/nssdb DOES NOT exists."
then
	if pgrep chrome &> /dev/null
	then 
		echo -e "\nClose Chrome or it will be killed in 8 seconds."
		sleep 8
		if pgrep chrome &> /dev/null
		then
			pkill chrome
			sleep 2
		fi
	fi
	sleep 2
	if pgrep chrome &> /dev/null
	then
		echo -e "\nChrome is still running. Exiting..."
		exit 0
	else
		echo -e "\nWhen required continue by pressing ENTER!\n"
		sleep 5
		mkdir -p $HOME/.pki/nssdb
		certutil -d $HOME/.pki/nssdb -N
		modutil -dbdir sql:$HOME/.pki/nssdb -add opensc-pkcs11 -libfile opensc-pkcs11.so -mechanisms FRIENDLY
	fi
else
	echo -e "\nDirectory $HOME/.pki/nssdb already exists.\n"
fi

manage icaclient $mode

if [ -d "/etc/linuxmint" ]
then
	echo -e "\nYou are on Mint. Mint up!\n"
	sleep 10
	if [ -d "/etc/opensc" ]
	then
		opensc_conf_file
	else
		echo -e "opensc folder doesn't exist..."
	fi
fi

exit 0
