#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"  # get cur dir of this script

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'          # No Color
YELLOW='\e[93m'      # Yellow
reset='\e[0m'         # reset



function setup_progress () {
  local setup_logfile=$DIR/log.log
  if [ -w $setup_logfile ]
  then
    echo "$( date ) : $1" >> "$setup_logfile"
  else
    echo "$( date ) : $1" >> "$setup_logfile" 2>&1
  fi
  echo -e "$2 $1${NC}"
}

function installDocker(){
    
    setupDocker

    verifyDockerInstallation
}

function verifyDockerInstallation(){
    #This command will list out all the groups that the current user is a part of, this hould list "docker" if installation was correct.
    groups
    
    #To test if Docker is working. You should see a message with the following text in it.
    #Hello from Docker!
    docker run hello-world
}

function setupDocker(){
    #download and run the official Docker setup script 
    curl -sSL https://get.docker.com | sh

    #For another user to be able to interact with Docker, it needs to be added to the docker group.
    #add our pi user to the docker group.
    sudo usermod -aG docker pi
    
    #need to log outa nd log back in for changes to take effect.
    logout

    verifyDockerInstallation
}

function set_portainer_volume {
	#read -p "Enter volume paths for '/var/run/docker.sock' and '/data' respectively. " sock portainerdata
	setup_progress "Enter volume paths for '/var/run/docker.sock' and '/data' respectively." $YELLOW
	read sock portainerdata

	mkdir -p $sock
	mkdir -p $portainerdata

	v_sock=$sock
	v_portainerdata=$portainerdata
}

function setupPortainer(){
    #download the docker image to your device.
    #sudo docker pull portainer/portainer-ce:latest

    #make directory for portainer container if does not exists already.
    set_portainer_volume

    #run portainer container 
    #sudo docker run -d -p 9000:9000 --name=portainer --restart=always -v /mnt/homeserver/portainer/containers/portainer/var/run/docker.sock:/var/run/docker.sock -v /mnt/homeserver/portainer/containers/portainer/portainer_data:/data portainer/portainer-ce:latest
    sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v $v_sock:/var/run/docker.sock -v $v_portainerdata:/data portainer/portainer-ce:latest
    
}

function replace_fstab {
	echo -n "UUID=$m_uuid" >> /etc/fstab 	# UUID of device
	echo -e -n "\t" >> /etc/fstab			# TAB
	echo -n "$m_dest" >> /etc/fstab			# Mount destination path
	echo -e -n "\t" >> /etc/fstab			# TAB
	#echo -n "$m_type" >> /etc/fstab		# Filesystem type
	echo -n "auto" >> /etc/fstab			# Automatically choose filesystem type
	echo -e -n "\t" >> /etc/fstab			# TAB
	echo -n "nofail,uid=1001,gid=1001,errors=remount-ro" >> /etc/fstab # USER ID, GROUP ID etc.
	echo -e -n "\t" >> /etc/fstab			# TAB
	echo -n "0" >> /etc/fstab				
	echo -e -n "\t" >> /etc/fstab			# TAB
	echo "1" >> /etc/fstab				
	
	setup_progress "'/etc/fstab' patched!" $GREEN
}

function set_type {
	setup_progress "Setting up '$1' to be mounted on startup ..." $YELLOW
	setup_progress "Type: $(sudo blkid -o value -s TYPE $1)" $YELLOW
	
	m_type=$(sudo blkid -o value -s TYPE $1)
	
	#case $(sudo blkid -o value -s TYPE $1) in
	#	"ntfs" ) echo "preparing NTFS";;
	#	* ) echo "Everything else";;
	#esac
	setup_progress "Filesystem type: $m_type" $YELLOW
	set_mount_path
}

function ask_path_creation {
    setup_progress "Do you wish to create $@ path? (y/n)? " $YELLOW
    read answer

    if [ "$answer" != "${answer#[Yy]}" ] ;then 
        mkdir -p $@
        setup_progress "Path '$@' was created." $YELLOW
        m_dest=$@
        replace_fstab
    else
        setup_progress "Goodbye!" $YELLOW
        break;
    fi
}

function set_mount_path {
	setup_progress "Enter mount destination: " $CYAN
	read dest
	if [ $dest != "" ] && [ -d $dest ]; then
		setup_progress "Path ok..." $YELLOW
		m_dest=$dest
		replace_fstab
	else
		setup_progress "Path '$dest' does not exist!" $RED
        ask_path_creation $dest
	fi
}

function ask_sure {
	options=("Yes")
	title="Selected '$1'"
	prompt="Automount '$1' ?"

	echo "$title"
	PS3="$prompt "
	select opt in "${options[@]}" "Quit"; do 

		case "$REPLY" in

		1 ) echo "Proceeding..."; m_device = $1;set_type $1;break;;

		$(( ${#options[@]}+1 )) ) echo "Goodbye!"; break;;
		*) echo "Invalid option. Try another one.";continue;;

		esac

	done
}

function createmenu ()
{
	#echo "Size of array: $#"
	#echo "$@"
	title="Devices"
	prompt="Pick a device ($(($#+1)) to exit):"

	echo "$title"
	PS3="$prompt "
  
	select option; do # in "$@" is the default
		if [ "$REPLY" -gt "$#" ];
		then
			setup_progress "Goodbye!" $YELLOW
			break;
		elif [ 1 -le "$REPLY" ] && [ "$REPLY" -le $(($#+0)) ];
		then
			#echo "You selected $option which is option $REPLY"
			m_uuid=$(echo $option | sed -e "s/^.*\((\)\(.*\)\()\).*$/\2/")
			setup_progress "Selected UUID: $m_uuid" $YELLOW
			ask_sure $option
			break;
		else
			printf "${RED}Incorrect Input: Select a number 1-$#${NC}\n"
		fi
	done
}

function select_device {
	devives_list=

	for DEVICE in $(sudo blkid -o device); do
		LABEL=$(sudo blkid -o value -s LABEL $DEVICE)
		UUID=$(sudo blkid -o value -s UUID $DEVICE)
		#echo "$DEVICE = $LABEL ($UUID)"
		devices_list[i]="$DEVICE = $LABEL ($UUID)"
		let i++
	done

	createmenu "${devices_list[@]}"
}

function mountExternalDrive(){
    setup_progress "Mounting external hird drive." $YELLOW
    
    select_device
    
    setup_progress "External hird drive mounted successfully." $YELLOW
}

function init(){
    #sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get autoremove -y && sudo apt-get autoclean
    setup_progress "********************************************************************************************" $YELLOW
    setup_progress "Updating OS, please wait..." $YELLOW
    sudo apt-get update && sudo apt-get dist-upgrade -y

    sudo timedatectl set-timezone America/Detroit    
}

function startSetup(){
    #init

    #mountExternalDrive
    
    #setupDocker

    #setupPortainer

    setup_progress "Setup done successfully." $YELLOW
}

startSetup