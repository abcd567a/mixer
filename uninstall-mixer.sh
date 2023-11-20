#!/bin/bash

echo -e "\e[1;95mStopping and disabling services \"mixer\" and \"pull@\" \e[39;0m"
systemctl stop pull@*
systemctl stop mixer
systemctl disable pull@.service
systemctl disable mixer.service
echo ""
echo -e "\e[1;32mDeleting Service Files \"mixer.service\" and \"pull@.service\" \e[39;0m"
rm /lib/systemd/system/mixer.service
rm /lib/systemd/system/pull@.service
echo ""
echo -e "\e[1;32mDeleting following two Lighttpd config files \e[39;0m"
echo -e "\e[1;32m  \"/etc/lighttpd/conf-enabled/89-mixer.conf\" \e[39;0m"
echo -e "\e[1;32m  \"/etc/lighttpd/conf-available/89-mixer.conf\" \e[39;0m"

rm /etc/lighttpd/conf-enabled/89-mixer.conf
rm /etc/lighttpd/conf-available/89-mixer.conf
echo ""
echo -e "\e[1;32mRemoving binary \"/usr/bin/mixer\" and Folder \"/usr/share/mixer\" \e[39;0m"
rm /usr/bin/mixer
rm -rf /usr/share/mixer
echo ""
echo -e "\e[1;32mRemoving mixer's config file \"/etc/default/mixer\" \e[39;0m"
rm /etc/default/mixer
echo ""
echo -e "\e[1;95mUninstall completed \e[39;0m"
echo ""
