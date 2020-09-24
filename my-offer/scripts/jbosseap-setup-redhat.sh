#!/bin/sh

adddate() {
    while IFS= read -r line; do
        printf '%s %s\n' "$(date "+%Y-%m-%d %H:%M:%S")" "$line";
    done
}

export EAP_HOME="/opt/rh/eap7/root/usr/share"
export EAP_RPM_CONF_STANDALONE="/etc/opt/rh/eap7/wildfly/eap7-standalone.conf"

JBOSS_EAP_USER=$1
JBOSS_EAP_PASSWORD=$2
RHSM_USER=$3
RHSM_PASSWORD=$4
RHSM_POOL=$5
IP_ADDR=$(hostname -I)
STORAGE_ACCOUNT_NAME=$6
CONTAINER_NAME=$7
STORAGE_ACCESS_KEY=$(echo "${8}" | openssl enc -d -base64)

echo "Initial JBoss EAP 7.2 setup" | adddate >> eap.log
echo "JBoss EAP admin user: " ${JBOSS_EAP_USER} | adddate >> eap.log
echo "Storage Account Name: " ${STORAGE_ACCOUNT_NAME} | adddate >> eap.log
echo "Storage Container Name: " ${CONTAINER_NAME} | adddate >> eap.log

echo "subscription-manager register --username RHSM_USER --password RHSM_PASSWORD" | adddate >> eap.log
subscription-manager register --username $RHSM_USER --password $RHSM_PASSWORD >> eap.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Red Hat Subscription Manager Registration Failed" | adddate >> eap.log; exit $flag;  fi
echo "subscription-manager attach --pool=EAP_POOL" | adddate  >> eap.log
subscription-manager attach --pool=${RHSM_POOL} >> eap.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Pool Attach for JBoss EAP Failed" | adddate  >> eap.log; exit $flag;  fi
echo "Subscribing the system to get access to JBoss EAP 7.2 repos" | adddate >> eap.log

# Install JBoss EAP 7.2
echo "subscription-manager repos --enable=jb-eap-7.2-for-rhel-8-x86_64-rpms" | adddate >> eap.log
subscription-manager repos --enable=jb-eap-7.2-for-rhel-8-x86_64-rpms >> eap.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! Enabling repos for JBoss EAP Failed" | adddate >> eap.log; exit $flag;  fi

echo "Installing JBoss EAP 7.2 repos" | adddate >> eap.log
echo "yum groupinstall -y jboss-eap7" | adddate >> eap.log
yum groupinstall -y jboss-eap7 >> eap.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP installation Failed" | adddate >> eap.log; exit $flag;  fi

echo "Copy the standalone-azure-ha.xml from EAP_HOME/doc/wildfly/examples/configs folder to EAP_HOME/wildfly/standalone/configuration folder" | adddate >> eap.log
echo "cp $EAP_HOME/doc/wildfly/examples/configs/standalone-azure-ha.xml $EAP_HOME/wildfly/standalone/configuration/" | adddate >> eap.log
cp $EAP_HOME/doc/wildfly/examples/configs/standalone-azure-ha.xml $EAP_HOME/wildfly/standalone/configuration/ | adddate >> eap.log 2>&1

echo "change the jgroups stack from UDP to TCP " | adddate >> eap.log
echo "sed -i 's/stack="udp"/stack="tcp"/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml" | adddate >> eap.log
sed -i 's/stack="udp"/stack="tcp"/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml | adddate >> eap.log 2>&1

echo "Update interfaces section update jboss.bind.address.management, jboss.bind.address and jboss.bind.address.private from 127.0.0.1 to 0.0.0.0" | adddate >> eap.log
echo "sed -i 's/jboss.bind.address.management:127.0.0.1/jboss.bind.address.management:0.0.0.0/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml" | adddate >> eap.log
sed -i 's/jboss.bind.address.management:127.0.0.1/jboss.bind.address.management:0.0.0.0/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml | adddate >> eap.log 2>&1
echo "sed -i 's/jboss.bind.address:127.0.0.1/jboss.bind.address:0.0.0.0/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml" | adddate >> eap.log
sed -i 's/jboss.bind.address:127.0.0.1/jboss.bind.address:0.0.0.0/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml | adddate >> eap.log 2>&1
echo "sed -i 's/jboss.bind.address.private:127.0.0.1/jboss.bind.address.private:0.0.0.0/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml" | adddate >> eap.log
sed -i 's/jboss.bind.address.private:127.0.0.1/jboss.bind.address.private:0.0.0.0/g'  $EAP_HOME/wildfly/standalone/configuration/standalone-azure-ha.xml | adddate >> eap.log 2>&1

echo "Start JBoss server" | adddate >> eap.log
echo "$EAP_HOME/wildfly/bin/standalone.sh -bprivate $IP_ADDR -b $IP_ADDR -bmanagement $IP_ADDR --server-config=standalone-azure-ha.xml -Djboss.jgroups.azure_ping.storage_account_name=$STORAGE_ACCOUNT_NAME -Djboss.jgroups.azure_ping.storage_access_key=STORAGE_ACCESS_KEY -Djboss.jgroups.azure_ping.container=$CONTAINER_NAME -Djava.net.preferIPv4Stack=true &" | adddate >> eap.log
$EAP_HOME/wildfly/bin/standalone.sh -bprivate $IP_ADDR -b $IP_ADDR -bmanagement $IP_ADDR --server-config=standalone-azure-ha.xml -Djboss.jgroups.azure_ping.storage_account_name=$STORAGE_ACCOUNT_NAME -Djboss.jgroups.azure_ping.storage_access_key=$STORAGE_ACCESS_KEY -Djboss.jgroups.azure_ping.container=$CONTAINER_NAME -Djava.net.preferIPv4Stack=true | adddate >> eap.log 2>&1 &
sleep 20

echo "export EAP_HOME="/opt/rh/eap7/root/usr/share"" >> /bin/jbossservice.sh
echo "$EAP_HOME/wildfly/bin/standalone.sh -bprivate $IP_ADDR -b $IP_ADDR -bmanagement $IP_ADDR --server-config=standalone-azure-ha.xml -Djboss.jgroups.azure_ping.storage_account_name=$STORAGE_ACCOUNT_NAME -Djboss.jgroups.azure_ping.storage_access_key=$STORAGE_ACCESS_KEY -Djboss.jgroups.azure_ping.container=$CONTAINER_NAME -Djava.net.preferIPv4Stack=true &" >> /bin/jbossservice.sh
chmod +x /bin/jbossservice.sh

yum install cronie cronie-anacron | adddate >> eap.log 2>&1
service crond start | adddate >> eap.log 2>&1
chkconfig crond on | adddate >> eap.log 2>&1
echo "@reboot sleep 90 && /bin/jbossservice.sh" >>  /var/spool/cron/root
chmod 600 /var/spool/cron/root

# Open Red Hat software firewall for port
echo "Configure firewall for ports" | adddate >> eap.log
echo "firewall-cmd --zone=public --add-port=8080/tcp --permanent" | adddate >> eap.log
sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent | adddate >> eap.log 2>&1
echo "firewall-cmd --zone=public --add-port=9990/tcp --permanent" | adddate >> eap.log
sudo firewall-cmd --zone=public --add-port=9990/tcp --permanent | adddate >> eap.log 2>&1
echo "firewall-cmd --zone=public --add-port=45700/tcp --permanent" | adddate >> eap.log
sudo firewall-cmd --zone=public --add-port=45700/tcp --permanent | adddate >> eap.log 2>&1
echo "firewall-cmd --zone=public --add-port=7600/tcp --permanent" | adddate >> eap.log
sudo firewall-cmd --zone=public --add-port=7600/tcp --permanent | adddate >> eap.log 2>&1
echo "firewall-cmd --reload" | adddate >> eap.log
sudo firewall-cmd --reload | adddate >> eap.log 2>&1
echo "iptables-save" | adddate >> eap.log
sudo iptables-save | adddate >> eap.log 2>&1

# Open Red Hat software firewall for port 22:
echo "firewall-cmd --zone=public --add-port=22/tcp --permanent" | adddate >> eap.log
firewall-cmd --zone=public --add-port=22/tcp --permanent | adddate >> eap.log 2>&1
echo "firewall-cmd --reload" | adddate >> eap.log
firewall-cmd --reload | adddate >> eap.log 2>&1

/bin/date +%H:%M:%S >> eap.log
echo "Configuring JBoss EAP management user" | adddate >> eap.log
echo "$EAP_HOME/wildfly/bin/add-user.sh -u JBOSS_EAP_USER -p JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup'" | adddate >> eap.log
$EAP_HOME/wildfly/bin/add-user.sh -u $JBOSS_EAP_USER -p $JBOSS_EAP_PASSWORD -g 'guest,mgmtgroup' >> eap.log 2>&1
flag=$?; if [ $flag != 0 ] ; then echo  "ERROR! JBoss EAP management user configuration Failed" | adddate >> eap.log; exit $flag;  fi 
# Seeing a race condition timing error so sleep to delay
sleep 20

echo "ALL DONE!" | adddate >> eap.log
/bin/date +%H:%M:%S >> eap.log