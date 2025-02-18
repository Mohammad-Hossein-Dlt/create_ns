#!/bin/bash

colored_text(){
  local color=$1
  local text=$2

  if [[ -z "$color" ]]; then
    color="32"
  fi
  echo -e "\e[${color}m$text\e[0m"
}

# این اسکریپت باید با دسترسی روت اجرا شود.
if [[ $EUID -ne 0 ]]; then
    color "31" "این اسکریپت باید با دسترسی روت اجرا شود."
    exit 1
fi

# تنظیم متغیرها
DOMAIN="example.com"
ZONE_DIR="/etc/bind/zones"
ZONE_FILE="${ZONE_DIR}/db.${DOMAIN}"
BIND_LOCAL_CONF="/etc/bind/named.conf.local"

# تنظیم نام و آدرس IP برای دو nameserver
NS_HOST1="ns1.${DOMAIN}"
NS_HOST2="ns2.${DOMAIN}"
NS_IP1="130.185.75.195"  # آدرس IP سرور اول (NS1)
NS_IP2="130.185.75.195"  # آدرس IP سرور دوم (NS2)

# آدرس IP اصلی دامنه (برای رکورد A دامنه و www)
DOMAIN_IP="130.185.75.195"

# ایمیل مدیر دامنه (در فایل SOA به صورت admin.example.com. نوشته می‌شود)
ADMIN_EMAIL="admin.${DOMAIN}"

colored_text "----- به‌روزرسانی لیست بسته‌ها و نصب BIND9 -----"
apt update
apt install -y bind9 bind9utils bind9-doc

colored_text "----- اضافه کردن zone ${DOMAIN} به فایل ${BIND_LOCAL_CONF} -----"
ZONE_CONFIG="zone \"${DOMAIN}\" {
    type master;
    file \"${ZONE_FILE}\";
};"

# بررسی می‌کند که اگر zone قبلاً اضافه نشده باشد، آن را اضافه کند.
if ! grep -q "zone \"${DOMAIN}\"" ${BIND_LOCAL_CONF}; then
    colored_text "${ZONE_CONFIG}" >> ${BIND_LOCAL_CONF}
    colored_text "Zone ${DOMAIN} به ${BIND_LOCAL_CONF} اضافه شد."
else
    colored_text "Zone ${DOMAIN} قبلاً در ${BIND_LOCAL_CONF} تنظیم شده است."
fi

colored_text "----- ایجاد دایرکتوری ${ZONE_DIR} در صورت عدم وجود -----"
if [ ! -d "${ZONE_DIR}" ]; then
    mkdir -p ${ZONE_DIR}
    colored_text "دایرکتوری ${ZONE_DIR} ایجاد شد."
fi

colored_text "----- ایجاد فایل zone در ${ZONE_FILE} -----"
cat > ${ZONE_FILE} <<EOF
;
; فایل داده BIND برای ${DOMAIN}
;
\$TTL    604800
@       IN      SOA     ${NS_HOST1}. ${ADMIN_EMAIL}. (
                              $(date +%Y%m%d01)  ; Serial (هر بار تغییر دهید)
                                   604800 ; Refresh
                                    86400 ; Retry
                                  2419200 ; Expire
                                   604800 ; Negative Cache TTL
)
;
; تعریف رکوردهای NS برای هر دو nameserver
@       IN      NS      ${NS_HOST1}.
@       IN      NS      ${NS_HOST2}.

; تعریف رکورد A برای هر nameserver
ns1     IN      A       ${NS_IP1}
ns2     IN      A       ${NS_IP2}

; تعریف رکوردهای A برای دامنه اصلی و www
@       IN      A       ${DOMAIN_IP}
www     IN      A       ${DOMAIN_IP}
EOF

colored_text "----- بررسی پیکربندی BIND -----"
named-checkconf
if [ $? -ne 0 ]; then
    colored_text "31" "خطا در پیکربندی BIND. اسکریپت خاتمه یافت."
    exit 1
fi

named-checkzone ${DOMAIN} ${ZONE_FILE}
if [ $? -ne 0 ]; then
    colored_text "31" "خطا در فایل zone ${ZONE_FILE}. اسکریپت خاتمه یافت."
    exit 1
fi

colored_text "----- راه‌اندازی مجدد سرویس BIND9 -----"
systemctl restart bind9

colored_text "تنظیمات DNS zone برای ${DOMAIN} با موفقیت انجام شد."
colored_text "برای تست، از دستور زیر استفاده کنید:"
colored_text "dig @localhost ${DOMAIN}"
