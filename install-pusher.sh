#!/bin/bash

set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR
###################################################################################################
echo -e "\e[1;35mCREATING SOCAT PIPES TO PUSH MIXED DATA FROM MIXER TO TARGET SITES \e[39;0m"
sleep 5
###################################################################################################

echo -e "\e[1;32mInstalling socat Package..... \e[39;0m"
sleep 2
apt install -y socat

echo -e "\e[1;32mCreating Scripts and Folders..... \e[39;0m"
sleep 2
INSTALL_FOLDER=/usr/share/pusher
if [[ ! -d ${INSTALL_FOLDER} ]];
then
echo -e "\e[32mCreating Installation Folder ${INSTALL_FOLDER} \e[39m"
mkdir ${INSTALL_FOLDER}
fi

echo -e "\e[1;32mCreating sub-folder \"vars\"..... \e[39;0m"
sleep 2
VARS_FOLDER=/usr/share/pusher/vars
if [[ ! -d ${VARS_FOLDER} ]];
then
echo -e "\e[32mCreating sub-folder ${VARS_FOLDER} \e[39m"
mkdir ${VARS_FOLDER}
fi

echo -e "\e[1;32mCreating Targets IP addresses file targets.ip \e[39;0m"
touch ${INSTALL_FOLDER}/targets.ip
echo "beast:feed1.adsbexchange.com:30004" > ${INSTALL_FOLDER}/targets.ip
echo "beast:feed.adsb.fi:30004" >> ${INSTALL_FOLDER}/targets.ip
echo "msg:data.adsbhub.org:5001" >> ${INSTALL_FOLDER}/targets.ip

echo -e "\e[1;32mCreating pusher script file pusher.sh \e[39;0m"
PUSHER_SCRIPT=${INSTALL_FOLDER}/pusher.sh
touch ${PUSHER_SCRIPT}
chmod 777 ${PUSHER_SCRIPT}
echo "Writing code to socat script file pusher.sh"
/bin/cat <<EOM >${PUSHER_SCRIPT}
#!/bin/bash

TARGETS=/usr/share/pusher/targets.ip
VARS_DIR=/usr/share/pusher/vars
systemctl stop push@*
rm \${VARS_DIR}/*
if  ! [[ -f \${TARGETS} ]]; then
   echo "TARGET CONFIG FILE DOES NOT EXIST....";
   echo "Create it by command: sudo nano \${TARGETS}  ";
   echo "and add target addresses to it ";
   echo "(one site per line) ";
   echo "in following format: ";
   echo "Data-Type:IP-Address:Port";
   echo "The Data-Type can be beast, msg, or avr, as per requirement of site";
   echo "";
   exit 0;

elif  [[ -f \${TARGETS} ]]; then
   if  ! [[ -s \${TARGETS} ]]; then
      echo "TARGET CONFIG FILE IS EMPTY....";
      echo "Open it by command: sudo nano \${TARGETS} ";
      echo "Add target addresses to it ";
      echo "(one site per line) ";
      echo "in following format: ";
      echo "Data-Type:IP-Address:Port";
      echo "The Data-Type can be beast, msg, or avr, as per requirement of site";
      echo "";
      exit 0;

   fi
fi

SRC=""
while read line;
do
[[ -z "\$line" ]] && continue
IFS=":" read F1 F2 F3 <<< \$line

if [[ \$F1 == "beast" ]]; then
SRC="127.0.0.1:40005";
elif [[ \$F1 == "msg" ]]; then
SRC="127.0.0.1:40003";
elif [[ \$F1 == "avr" ]]; then
SRC="127.0.0.1:40002";
fi

echo var1="\${SRC}" > \${VARS_DIR}/\${F2}
echo var2="\${F2}" >> \${VARS_DIR}/\${F2}
echo var3="\${F3}" >> \${VARS_DIR}/\${F2}

systemctl restart push@\${F2}
echo "Created push@"\${F2};

done < \${TARGETS}
EOM

chmod +x ${PUSHER_SCRIPT}


echo -e "\e[1;32mCreating push-connector script file push-connector.sh \e[39;0m"
PUSH_CONNECTOR_SCRIPT=${INSTALL_FOLDER}/push-connector.sh
touch ${PUSH_CONNECTOR_SCRIPT}
chmod 777 ${PUSH_CONNECTOR_SCRIPT}
echo "Writing code to script file push-connector.sh"
/bin/cat <<EOM >${PUSH_CONNECTOR_SCRIPT}
#!/bin/bash

OPT="keepalive,keepidle=30,keepintvl=30,keepcnt=2,connect-timeout=30,retry=2,interval=15"
CMD=""
CMD="socat -dd -u TCP:\$1,\${OPT} TCP:\$2:\$3,\${OPT} ";
while true
    do
      echo "CONNECTING MIXER TO TARGET"
      eval "\${CMD}"
      echo "LOST CONNECTION OF MIXER AND TARGET"
      echo "RE-CONNECTING MIXER TO TARGET"
     sleep 30
   done

EOM

chmod +x ${PUSH_CONNECTOR_SCRIPT}

## echo -e "\e[1;32mCreating user \"push\" to run the push services.... \e[39;0m"
## if id -u push >/dev/null 2>&1; then
##  echo "user push exists"
## else
##  echo "user push does not exist, creating user push"
##   useradd --system push
##  echo "Giving ownership of " ${INSTALL_FOLDER} " and all of it's contents (Recursive) to user \"push\' ...."
##  chown push:push -R ${INSTALL_FOLDER}
##fi

echo -e "\e[1;32mCreating systemd service file for pusher \e[39;0m"
PUSHER_SERVICE=/lib/systemd/system/pusher.service
touch ${PUSHER_SERVICE}
chmod 777 ${PUSHER_SERVICE}
echo "Writing code to service file pusher.service"
/bin/cat <<EOM >${PUSHER_SERVICE}
# socat pusher service - by abcd567

[Unit]
Description=pusher service by abcd567
Wants=network.target
After=network.target

[Service]
## User=push
RuntimeDirectory=pusher
RuntimeDirectoryMode=0755
ExecStart=/usr/share/pusher/pusher.sh
SyslogIdentifier=pusher
Type=simple
Restart=on-failure
RestartSec=30
RestartPreventExitStatus=64
#Nice=-5

[Install]
WantedBy=default.target
EOM
chmod 644 ${PUSHER_SERVICE}

systemctl enable pusher
systemctl restart pusher

echo -e "\e[1;32mCreating systemd service file for push@.service \e[39;0m"
PUSH_AT_SERVICE=/lib/systemd/system/push@.service
touch ${PUSH_AT_SERVICE}
chmod 777 ${PUSH_AT_SERVICE}
echo "Writing code to service file push@.service"
/bin/cat <<EOM >${PUSH_AT_SERVICE}
# socat push@.service - by abcd567

[Unit]
Description=push@.service by abcd567
Wants=network.target
After=network.target

[Service]
## User=push
EnvironmentFile=/usr/share/pusher/vars/%i
RuntimeDirectory=push-%i
RuntimeDirectoryMode=0755
ExecStart=/usr/share/pusher/push-connector.sh \${var1} \${var2} \${var3}
SyslogIdentifier=push-%i
Type=simple
Restart=on-failure
RestartSec=30
RestartPreventExitStatus=64
#Nice=-5

[Install]
WantedBy=default.target
EOM
chmod 644 ${PUSH_AT_SERVICE}


#######################################################################################################
echo ""
echo -e "\e[1;32mINSTALLATION OF SOCAT PIPES FOR PUSHING DATA FROM MIXER TO SITES COMPLETED \e[39;0m"
echo ""
#######################################################################################################
echo -e "\e[1;95mIMPORTANT:  \e[39;0m"
echo -e "\e[1;39m    sudo nano /usr/share/pusher/targets.ip \e[39;0m"
echo -e "\e[1;32min above file add IP's of your target sites in format\e[39;0m"
echo -e "\e[1;39m[DATA_TYPE]:[IP_ADDRESS]:[PORT] \e[39;0m"
echo -e "\e[1;32mOne Site per line, like EXAMPLES below \e[39;0m"
echo ""
echo -e "\e[1;39mmsg:data.adsbhub.org:5001 \e[39;0m"
echo -e "\e[1;39mbeast:94.130.23.233:5004 \e[39;0m"
echo ""
echo -e "\e[1;32mAfter adding target sites config and saving the file, \e[39m"
echo -e "\e[1;32mrestart push connections by following command: \e[39m"
echo -e "\e[1;39m    sudo systemctl restart pusher  \e[39;0m"
echo ""
