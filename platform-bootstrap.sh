#!/bin/bash

#-----------------------------------------------------------------------
# Add the keys to the server so you can get to github safely without
# need for a prompt which salt will not handle correctly
#-----------------------------------------------------------------------
yum install -y openssh-clients
[ -d ~/.ssh ] || mkdir -p ~/.ssh

# set up a config just incase to clear ssh warnings
if [ ! -z $(grep "Host *" ~/.ssh/config) ]; then
    echo -e "Host *\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile /dev/null\n\tLogLevel ERROR" >> ~/.ssh/config
    echo "ssh warning suppression applied"
else
    echo "host * ssh warning suppression already applied"
fi
# just to be extra safe add github directly to them
touch ~/.ssh/known_hosts
ssh-keygen -R 192.30.252.128
ssh-keyscan -H 192.30.252.128 >> ~/.ssh/known_hosts
ssh-keygen -R 192.30.252.129
ssh-keyscan -H 192.30.252.129 >> ~/.ssh/known_hosts
ssh-keygen -R 192.30.252.130
ssh-keyscan -H 192.30.252.130 >> ~/.ssh/known_hosts
ssh-keygen -R 192.30.252.130
ssh-keyscan -H 192.30.252.131 >> ~/.ssh/known_hosts
ssh-keygen -R github.com
ssh-keyscan -H github.com >> ~/.ssh/known_hosts

yum clean all
yum -y install unzip

yum search kernel-headers  --disableexcludes=all
yum -y install kernel-headers  --disableexcludes=all

mkdir -p /var/www

if [ ! -h /usr/sbin/gitploy ]; then
    curl  https://raw.githubusercontent.com/jeremyBass/gitploy/master/gitploy | sudo sh -s -- install
    [ -h /usr/sbin/gitploy ] || echoerr "gitploy failed install"
else
    gitploy update_gitploy
fi

#load up the main wordpress installer
gitploy init 2>&1 | grep -qi "already initialized" && echo ""
gitploy ls 2>&1 | grep -qi "wp_platform" && gitploy up wp_platform
gitploy ls 2>&1 | grep -qi "wp_platform" || gitploy add -p /tmp/wsu-platform -b master wp_platform git@github.com:jeremyBass/jeremybass-wsuwp-platform.git

cp -fr /tmp/wsu-platform/pillar /srv/
cp -fr /tmp/wsu-platform/www /var/

cd /

mkdir -p /srv/pillar/
mkdir -p /srv/pillar/config/
touch /srv/pillar/top.sls
touch /srv/pillar/network.sls
touch /srv/pillar/mysql.sls

#load up custom parts
gitploy init 2>&1 | grep -qi "already initialized" && echo ""
gitploy ls 2>&1 | grep -qi "platform_parts" && gitploy up platform_parts && gitploy re platform_parts
gitploy ls 2>&1 | grep -qi "platform_parts" || gitploy clone -b master platform_parts git@github.com:jeremyBass/jeremybass-platform-parts.git


[ -d /tmp/wsu-web ] || mkdir -p /tmp/wsu-web

#load up the wp core
gitploy init 2>&1 | grep -qi "already initialized" && echo ""
gitploy ls 2>&1 | grep -qi "wp_provisioner" && gitploy up wp_provisioner
gitploy ls 2>&1 | grep -qi "wp_provisioner" || gitploy add -p /tmp/wsu-web -b master wp_provisioner git@github.com:jeremyBass/jeremybass-wp.git

cp -fr /tmp/wsu-web/provision/salt /srv/
cp /tmp/wsu-web/provision/salt/config/yum.conf /etc/yum.conf

rpm -Uvh --force http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
sed -i 's/mirrorlist=https/mirrorlist=http/' /etc/yum.repos.d/epel.repo
yum -y update python

sh /tmp/wsu-web/provision/bootstrap_salt.sh -K stable
rm /etc/salt/minion.d/*.conf
rm /etc/salt/minion_id
echo "wsuwp-prod" > /etc/salt/minion_id
cp /tmp/wsu-web/provision/salt/minions/wsuwp.conf /etc/salt/minion.d/

salt-call --local --log-level=info --config-dir=/etc/salt state.highstate



#load up the wp core
gitploy init 2>&1 | grep -qi "already initialized" && echo ""
gitploy ls 2>&1 | grep -qi "wsuwp_plugins" && gitploy up wsuwp_plugins
gitploy ls 2>&1 | grep -qi "wsuwp_plugins" || gitploy add -p /var/www/wp-content/plugins/ -b master wsuwp_plugins https://github.com/washingtonstateuniversity/WSUWP-Build-Plugins-Public.git

#load up the wp core
gitploy init 2>&1 | grep -qi "already initialized" && echo ""
gitploy ls 2>&1 | grep -qi "wsuwp_themes" && gitploy up wsuwp_themes
gitploy ls 2>&1 | grep -qi "wsuwp_themes" || gitploy add -p /var/www/wp-content/themes/ -b master wsuwp_themes https://github.com/washingtonstateuniversity/WSUWP-Build-Themes-Public.git
