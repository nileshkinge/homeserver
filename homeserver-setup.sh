#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"  # get cur dir of this script

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'          # No Color
IYellow='\e[93m'      # Yellow
reset='\e[0m'         # reset



function setup_progress () {
  local setup_logfile=$DIR/log.log
  if [ -w $setup_logfile ]
  then
    echo "$( date ) : $*" >> "$setup_logfile"
  else
    echo "$( date ) : $*" >> "$setup_logfile" 2>&1
  fi
  echo "$@"
}

function install_xrdp(){
    setup_progress "Installing XRDP, please wait..."
    sudo apt-get install xrdp -y
}

function enable_camera(){
    echo "0 = ENABLED, 1 = DISABLED"
    #sudo raspi-config nonint do_camera 0
    cam=$(sudo raspi-config nonint get_camera 0)
    if [ $cam == 0 ]
    then
    setup_progress "Camera Enabled"
    else
    setup_progress "Camera is Disabled, enabeling it now"
    sudo raspi-config nonint do_camera 0
    setup_progress "Camera is Enabled."
    fi
}

function enable_ssh(){
    varssh=$(sudo raspi-config nonint get_ssh 0)
    if [ $varssh == 0 ]
    then
    setup_progress "SSH Enabled"
    else
    setup_progress "SSH is Disabled, enabeling it now"
    sudo raspi-config nonint do_ssh 0
    setup_progress "SSH is Enabled."
    fi
}

function enable_vnc(){
    #sudo raspi-config nonint do_vnc 0
    varVNC=$(raspi-config nonint get_vnc 0)
    if [ $varVNC == 0 ]
    then
    setup_progress "VNC Enabled"
    else
    setup_progress "VNC is Disabled, enabeling it now"
    sudo raspi-config nonint do_vnc 0
    setup_progress "VNC is Enabled."
    fi
}

function enable_remote_GPIO(){
    #sudo raspi-config nonint do_rgpio 0
    varRGPIO=$(raspi-config nonint get_rgpio 0)
    if [ $varRGPIO == 0 ]
    then
    setup_progress "Remote GPIO Enabled"
    else
    setup_progress "Remote GPIO is Disabled, enabeling it now"
    sudo raspi-config nonint do_rgpio 0
    setup_progress "Remote GPIO is Enabled"
    fi
}

function install_rclone(){
    read -p "$(echo -e $IYellow "Do you want to install rclone? (Y/N): "$reset)" wantToInstallRclone
    if [[ "$wantToInstallRclone" == "Y" || "$wantToInstallRclone" == "y" ]]
    then
        setup_progress "installing rclone"
        sudo -v ; curl https://rclone.org/install.sh | sudo bash
        setup_progress "rclone installed successfully."
        setup_progress "Please run 'rclone config' command to configure rclone remote. https://rclone.org/docs/"
    fi    
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

function setupPortainer(){
    #download the docker image to your device.
    sudo docker pull portainer/portainer-ce:latest

    #make directory for portainer container if does not exists already.
    mkdir -p /mnt/seagateDisk/portainer/containers/portainer/portainer_data

    #run portainer container 
    #sudo docker run -d -p 9000:9000 --name=portainer --restart=always -v /mnt/seagateDisk/portainer/containers/portainer/var/run/docker.sock:/var/run/docker.sock -v /mnt/seagateDisk/portainer/containers/portainer/portainer_data:/data portainer/portainer-ce:latest
    sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /mnt/seagateDisk/portainer/containers/portainer/var/run/docker.sock:/var/run/docker.sock -v /mnt/seagateDisk/portainer/containers/portainer/portainer_data:/data portainer/portainer-ce:latest
    
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
	
	printf "${GREEN}'/etc/fstab' patched!${NC}\n"
}

function set_type {
	echo "Setting up '$1' to be mounted on startup ..."
	echo "Type: $(sudo blkid -o value -s TYPE $1)"
	
	m_type=$(sudo blkid -o value -s TYPE $1)
	
	#case $(sudo blkid -o value -s TYPE $1) in
	#	"ntfs" ) echo "preparing NTFS";;
	#	* ) echo "Everything else";;
	#esac
	echo "Filesystem type: $m_type"
	set_mount_path
}

function set_mount_path {
	printf "${CYAN}Enter mount destination: ${NC}\n"
	read dest
	if [ $dest != "" ] && [ -d $dest ]; then
		echo "Path ok..."
		m_dest=$dest
		replace_fstab
	else
		printf "${RED}Path '$dest' does not exist!${NC}\n"
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

createmenu ()
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
			echo "Goodbye!"
			break;
		elif [ 1 -le "$REPLY" ] && [ "$REPLY" -le $(($#+0)) ];
		then
			#echo "You selected $option which is option $REPLY"
			m_uuid=$(echo $option | sed -e "s/^.*\((\)\(.*\)\()\).*$/\2/")
			#echo "Selected UUID: $m_uuid"
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
    setup_progress "Mounting external hird drive."
    
    select_device
    
    setup_progress "External hird drive mounted successfully."
}

function init(){
    #sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get autoremove -y && sudo apt-get autoclean
    setup_progress "********************************************************************************************"
    setup_progress "Updating OS, please wait..."
    sudo apt-get update && sudo apt-get dist-upgrade -y

    sudo timedatectl set-timezone America/Detroit    
}

function startSetup(){
    #init

    #install_xrdp
    
    #enable_camera

    #enable_ssh

    #mountExternalDrive
    
    #setupDocker

    #setupPortainer

    setup_progress "Setup done successfully."
}

startSetup