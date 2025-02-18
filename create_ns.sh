#!/bin/bash
# Script: create_dns_zone.sh
# Purpose: Create a DNS Zone for a specified domain with two NS records on an Ubuntu server using BIND9.
#
# Make sure you have sudo privileges before running this script.
# Adjust the settings (DOMAIN, NS1, NS2, and IP addresses) as needed.

colored_text(){
  local color=$1
  local text=$2

  if [[ -z "$color" ]]; then
    color="32"
  fi
  echo -e "\e[${color}m$text\e[0m"
}

# Variables
DOMAIN="example.com"
ZONE_DIR="/etc/bind/zones"
ZONE_FILE="${ZONE_DIR}/${DOMAIN}.db"
NS1="ns1.${DOMAIN}."
NS2="ns2.${DOMAIN}."
NS1_IP="130.185.75.195"
NS2_IP="130.185.75.195"
ADMIN_EMAIL="admin.${DOMAIN}."

# Install BIND9 if it is not installed
if ! dpkg -l | grep -q bind9; then
    echo "BIND9 not found, installing..."
    sudo apt-get update
    sudo apt-get install -y bind9 bind9utils bind9-doc
fi

# Create the zone directory if it doesn't exist
if [ ! -d "${ZONE_DIR}" ]; then
    echo "Creating directory ${ZONE_DIR}"
    sudo mkdir -p "${ZONE_DIR}"
fi

# Backup the existing named.conf.local file
echo "Backing up /etc/bind/named.conf.local"
sudo cp /etc/bind/named.conf.local /etc/bind/named.conf.local.bak

# Add zone configuration to named.conf.local if not already present
if ! grep -q "zone \"${DOMAIN}\"" /etc/bind/named.conf.local; then
    echo "Adding zone configuration for ${DOMAIN} to /etc/bind/named.conf.local"
    sudo bash -c "cat >> /etc/bind/named.conf.local <<EOF

zone \"${DOMAIN}\" {
    type master;
    file \"${ZONE_FILE}\";
};
EOF"
else
    echo "Zone configuration for ${DOMAIN} already exists."
fi

# Determine the new serial number by reading the old serial from the zone file if it exists

NEW_SERIAL=$(date +%Y%m%d01)

colored_text NEW_SERIAL

# Create the zone file with SOA and NS records without comments
echo "Creating zone file at ${ZONE_FILE}"
sudo bash -c "cat > ${ZONE_FILE}" <<EOF
\$TTL    604800
@       IN      SOA     ${NS1} ${ADMIN_EMAIL} (
                             ${NEW_SERIAL}
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
