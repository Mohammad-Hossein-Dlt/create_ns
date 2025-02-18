#!/bin/bash
# Script: create_dns_zone.sh
# Purpose: Remove any existing BIND9 installation, reinstall it, and then create a DNS Zone for a specified domain with two NS records on an Ubuntu server.
#
# Make sure you have sudo privileges before running this script.
# Adjust the settings (DOMAIN, NS1, NS2, and IP addresses) as needed.

# Variables
DOMAIN="example.com"
ZONE_DIR="/etc/bind/zones"
ZONE_FILE="${ZONE_DIR}/${DOMAIN}.db"
NS1="ns1.${DOMAIN}."
NS2="ns2.${DOMAIN}."
NS1_IP="130.185.75.195"
NS2_IP="130.185.75.195"
ADMIN_EMAIL="admin.${DOMAIN}."

# Completely remove any existing BIND9 installation
echo "Purging any existing BIND9 installation..."
sudo apt-get purge -y bind9 bind9utils bind9-doc
sudo apt-get autoremove -y

# Update package lists and reinstall BIND9
echo "Installing BIND9..."
sudo apt-get update
sudo apt-get install -y bind9 bind9utils bind9-doc

# Create the zone directory if it doesn't exist
if [ ! -d "${ZONE_DIR}" ]; then
    echo "Creating directory ${ZONE_DIR}"
    sudo mkdir -p "${ZONE_DIR}"
fi

# Backup the existing named.conf.local file if it exists
if [ -f /etc/bind/named.conf.local ]; then
    echo "Backing up /etc/bind/named.conf.local"
    sudo cp /etc/bind/named.conf.local /etc/bind/named.conf.local.bak
fi

# Remove any previous zone configuration for the domain from named.conf.local to avoid duplicates
sudo sed -i "/zone \"${DOMAIN}\" {/,/};/d" /etc/bind/named.conf.local

# Add zone configuration to named.conf.local
echo "Adding zone configuration for ${DOMAIN} to /etc/bind/named.conf.local"
sudo bash -c "cat >> /etc/bind/named.conf.local <<EOF

zone \"${DOMAIN}\" {
    type master;
    file \"${ZONE_FILE}\";
};
EOF"

# Determine the new serial number by timestamp
NEW_SERIAL=$(date +%s)

# Create the zone file with SOA and NS records (without inline comments)
echo "Creating zone file at ${ZONE_FILE}"
sudo bash -c "cat > ${ZONE_FILE}" <<EOF
\$TTL    604800
@       IN      SOA     ${NS1} ${ADMIN_EMAIL} (
                             $NEW_SERIAL
                             604800
                             86400
                             2419200
                             604800 )
@       IN      NS      ${NS1}
@       IN      NS      ${NS2}
ns1     IN      A       ${NS1_IP}
ns2     IN      A       ${NS2_IP}
EOF

# Check the BIND configuration
echo "Checking BIND configuration"
sudo named-checkconf

# Check the zone file for validity
echo "Checking zone file for ${DOMAIN}"
sudo named-checkzone ${DOMAIN} ${ZONE_FILE}

# Restart the BIND9 service
echo "Restarting BIND9 service"
sudo systemctl restart bind9

echo "DNS Zone for ${DOMAIN} with NS records ${NS1} and ${NS2} has been created successfully."
