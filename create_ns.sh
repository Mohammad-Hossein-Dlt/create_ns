#!/bin/bash
# This script must be run as root.
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Set variables
DOMAIN="example.com"
ZONE_DIR="/etc/bind/zones"
ZONE_FILE="${ZONE_DIR}/db.${DOMAIN}"
BIND_LOCAL_CONF="/etc/bind/named.conf.local"

# Set names and IP addresses for two nameservers
NS_HOST1="ns1.${DOMAIN}"
NS_HOST2="ns2.${DOMAIN}"
NS_IP1="130.185.75.195"  # IP address for the first nameserver (NS1)
NS_IP2="130.185.75.195"  # IP address for the second nameserver (NS2)

# Domain main IP address (for A records of the domain and www)
DOMAIN_IP="130.185.75.195"

# Domain admin email (in the SOA record, it appears as admin.example.com.)
ADMIN_EMAIL="admin.${DOMAIN}"

echo "----- Updating package list and installing BIND9 -----"
apt update
apt install -y bind9 bind9utils bind9-doc

echo "----- Adding zone ${DOMAIN} to ${BIND_LOCAL_CONF} -----"
ZONE_CONFIG="zone \"${DOMAIN}\" {
    type master;
    file \"${ZONE_FILE}\";
};"

# Check if the zone is already configured; if not, add it.
if ! grep -q "zone \"${DOMAIN}\"" ${BIND_LOCAL_CONF}; then
    echo -e "\n${ZONE_CONFIG}" >> ${BIND_LOCAL_CONF}
    echo "Zone ${DOMAIN} added to ${BIND_LOCAL_CONF}."
else
    echo "Zone ${DOMAIN} is already configured in ${BIND_LOCAL_CONF}."
fi

echo "----- Creating directory ${ZONE_DIR} if it does not exist -----"
if [ ! -d "${ZONE_DIR}" ]; then
    mkdir -p ${ZONE_DIR}
    echo "Directory ${ZONE_DIR} created."
fi

echo "----- Creating zone file at ${ZONE_FILE} -----"
cat > ${ZONE_FILE} <<EOF
;
; BIND data file for ${DOMAIN}
;
\$TTL    604800
@       IN      SOA     ${NS_HOST1}. ${ADMIN_EMAIL}. (
                              $(date +%Y%m%d01)  ;
                                   604800 ; Refresh
                                    86400 ; Retry
                                  2419200 ; Expire
                                   604800 ; Negative Cache TTL
)
;
@       IN      NS      ${NS_HOST1}.
@       IN      NS      ${NS_HOST2}.

ns1     IN      A       ${NS_IP1}
ns2     IN      A       ${NS_IP2}

@       IN      A       ${DOMAIN_IP}
www     IN      A       ${DOMAIN_IP}
EOF

echo "----- Checking BIND configuration -----"
named-checkconf
if [ $? -ne 0 ]; then
    echo "Error in BIND configuration. Exiting script."
    exit 1
fi

named-checkzone ${DOMAIN} ${ZONE_FILE}
if [ $? -ne 0 ]; then
    echo "Error in zone file ${ZONE_FILE}. Exiting script."
    exit 1
fi

echo "----- Restarting BIND9 service -----"
systemctl restart bind9

echo "DNS zone setup for ${DOMAIN} completed successfully."
echo "To test, use the following command:"
echo "dig @localhost ${DOMAIN}"
