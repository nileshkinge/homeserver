#!/bin/bash

IYellow='\e[93m'      # Yellow
reset='\e[0m'         # reset

function setup_progress () {
  local setup_logfile=/home/pi/dashcam/code/dashCam-setup.log
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

function setup_dashcam_cronjob(){
#!/bin/bash
    #write out current crontab
    crontab -l > dashcamcron

    setup_progress "Path is set to: $PATH"
    echo "PATH=/bin:/usr/bin:/sbin:/usr/sbin" >> dashcamcron

    #echo new cron into cron file
    echo "@reboot python3 /home/pi/dashcam/code/dashCam.py >>/home/pi/dashcam/code/log.log 2>&1" >> dashcamcron
    
    crontab dashcamcron
    rm dashcamcron
}

function setup_email(){
    read -p "$(echo -e $IYellow "Do you want to setup email? (Y/N): "$reset)" wantToSetupEmail

    if [[ "$wantToSetupEmail" == "Y" || "$wantToSetupEmail" == "y" ]]
    then
        read -p "$(echo -e $IYellow "Enter 'To: ' email: "$reset)" toEmail
        read -p "$(echo -e $IYellow "Enter 'From: ' email (gmail account): "$reset)" fromEmail
        read -sp "$(echo -e $IYellow "Enter your gmail password: "$reset)" gmailPassword

        python3 -c'import mail; mail.initValues("'$toEmail'", "'$fromEmail'", "'$gmailPassword'")'

        setup_progress "adding mailer cron job"
        crontab -l > dashcamcron
        echo "@reboot sleep 300 && python3 /home/pi/dashcam/code/mailer.py >>/home/pi/dashcam/code/log.log 2>&1" >> dashcamcron
        #install new cron file
        crontab dashcamcron
        rm dashcamcron
    fi
}

function setup_UI(){
    read -p "$(echo -e $IYellow "Do you want to setup UI? (Y/N): "$reset)" wantToSetupWebUi

    if [[ "$wantToSetupWebUi" == "Y" || "$wantToSetupWebUi" == "y" ]]
    then    
        setup_progress "Installing node js"
        curl -o node-v9.7.1-linux-armv6l.tar.gz https://nodejs.org/dist/v9.7.1/node-v9.7.1-linux-armv6l.tar.gz
        tar -xzf node-v9.7.1-linux-armv6l.tar.gz
        sudo cp -r node-v9.7.1-linux-armv6l/* /usr/local/
        node -v && npm -v
        setup_progress "node js installed successfully"

        setup_progress "install web app dependencies"
        sudo npm install /home/pi/dashcam/code/web

        setup_progress "adding mailer cron job"
        crontab -l > dashcamcron
        echo "@reboot sudo /usr/local/bin/node /home/pi/dashcam/code/web/app.js >>/home/pi/dashcam/code/log.log 2>&1" >> dashcamcron
        #install new cron file
        crontab dashcamcron
        rm dashcamcron    

        setup_progress "web app dependencies installed successfully."
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

function setup_accesspoint(){
    read -p "$(echo -e $IYellow "Do you want to setup as access point? (Y/N): "$reset)" wantToSetupAP
    if [[ "$wantToSetupAP" == "Y" || "$wantToSetupAP" == "y" ]]
    then
        setup_progress "Setting up access point."
        /bin/bash apSetup.sh dashcam
        setup_progress "access point setup successfull."
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
    
    #run portainer container 
    sudo docker run -d -p 9000:9000 --name=portainer --restart=always -v /mnt/seagateDisk/portainer/containers/portainer/var/run/docker.sock:/var/run/docker.sock -v /mnt/seagateDisk/portainer/containers/portainer/portainer_data:/data portainer/portainer-ce:latest
    
}

function init(){
    #sudo apt-get update && sudo apt-get dist-upgrade -y && sudo apt-get autoremove -y && sudo apt-get autoclean
    setup_progress "********************************************************************************************"
    setup_progress "Updating OS, please wait..."
    sudo apt-get update && sudo apt-get dist-upgrade -y

    sudo timedatectl set-timezone America/Detroit    
}

function startSetup(){
    init

    install_xrdp
    
    enable_camera

    enable_ssh

    setupDocker

    setupPortainer

    setup_progress "Setup done successfully."
}

startSetup


#define SET_HOSTNAME    "sudo raspi-config nonint do_hostname %s"
#define GET_BOOT_CLI    "sudo raspi-config nonint get_boot_cli"
#define GET_AUTOLOGIN   "sudo raspi-config nonint get_autologin"
#define SET_BOOT_CLI    "sudo raspi-config nonint do_boot_behaviour B1"
#define SET_BOOT_CLIA   "sudo raspi-config nonint do_boot_behaviour B2"
#define SET_BOOT_GUI    "sudo raspi-config nonint do_boot_behaviour B3"
#define SET_BOOT_GUIA   "sudo raspi-config nonint do_boot_behaviour B4"
#define GET_BOOT_WAIT   "sudo raspi-config nonint get_boot_wait"
#define SET_BOOT_WAIT   "sudo raspi-config nonint do_boot_wait %d"
#define GET_SPLASH      "sudo raspi-config nonint get_boot_splash"
#define SET_SPLASH      "sudo raspi-config nonint do_boot_splash %d"
#define GET_OVERSCAN    "sudo raspi-config nonint get_overscan"
#define SET_OVERSCAN    "sudo raspi-config nonint do_overscan %d"
#define GET_CAMERA      "sudo raspi-config nonint get_camera"
#define SET_CAMERA      "sudo raspi-config nonint do_camera %d"
#define GET_SSH         "sudo raspi-config nonint get_ssh"
#define SET_SSH         "sudo raspi-config nonint do_ssh %d"
#define GET_VNC         "sudo raspi-config nonint get_vnc"
#define SET_VNC         "sudo raspi-config nonint do_vnc %d"
#define GET_SPI         "sudo raspi-config nonint get_spi"
#define SET_SPI         "sudo raspi-config nonint do_spi %d"
#define GET_I2C         "sudo raspi-config nonint get_i2c"
#define SET_I2C         "sudo raspi-config nonint do_i2c %d"
#define GET_SERIAL      "sudo raspi-config nonint get_serial"
#define GET_SERIALHW    "sudo raspi-config nonint get_serial_hw"
#define SET_SERIAL      "sudo raspi-config nonint do_serial %d"
#define GET_1WIRE       "sudo raspi-config nonint get_onewire"
#define SET_1WIRE       "sudo raspi-config nonint do_onewire %d"
#define GET_RGPIO       "sudo raspi-config nonint get_rgpio"
#define SET_RGPIO       "sudo raspi-config nonint do_rgpio %d"
#define GET_PI_TYPE     "sudo raspi-config nonint get_pi_type"
#define GET_OVERCLOCK   "sudo raspi-config nonint get_config_var arm_freq /boot/config.txt"
#define SET_OVERCLOCK   "sudo raspi-config nonint do_overclock %s"
#define GET_GPU_MEM     "sudo raspi-config nonint get_config_var gpu_mem /boot/config.txt"
#define GET_GPU_MEM_256 "sudo raspi-config nonint get_config_var gpu_mem_256 /boot/config.txt"
#define GET_GPU_MEM_512 "sudo raspi-config nonint get_config_var gpu_mem_512 /boot/config.txt"
#define GET_GPU_MEM_1K  "sudo raspi-config nonint get_config_var gpu_mem_1024 /boot/config.txt"
#define SET_GPU_MEM     "sudo raspi-config nonint do_memory_split %d"
#define GET_HDMI_GROUP  "sudo raspi-config nonint get_config_var hdmi_group /boot/config.txt"
#define GET_HDMI_MODE   "sudo raspi-config nonint get_config_var hdmi_mode /boot/config.txt"
#define SET_HDMI_GP_MOD "sudo raspi-config nonint do_resolution %d %d"
#define GET_WIFI_CTRY   "sudo raspi-config nonint get_wifi_country"
#define SET_WIFI_CTRY   "sudo raspi-config nonint do_wifi_country %s"
#define CHANGE_PASSWD   "(echo \"%s\" ; echo \"%s\" ; echo \"%s\") | passwd"
#END