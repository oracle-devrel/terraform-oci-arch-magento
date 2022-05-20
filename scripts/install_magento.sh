#!/bin/bash
#set -x

export use_shared_storage='${use_shared_storage}'
export use_redis_cache='${use_redis_cache}'
export use_redis_as_cache_backend='${use_redis_as_cache_backend}'
export use_redis_as_page_cache='${use_redis_as_page_cache}'
export install_sample_data='${install_sample_data}'

if [[ $use_shared_storage == "true" ]]; then
  echo "Mount NFS share: ${magento_shared_working_dir}"
  yum install -y -q nfs-utils
  mkdir -p ${magento_shared_working_dir}
  echo '${mt_ip_address}:${magento_shared_working_dir} ${magento_shared_working_dir} nfs nosharecache,context="system_u:object_r:httpd_sys_rw_content_t:s0" 0 0' >> /etc/fstab
  setsebool -P httpd_use_nfs=1
  mount ${magento_shared_working_dir}
  mount
  echo "NFS share mounted."
  cd ${magento_shared_working_dir}
else
  echo "No mount NFS share. Moving to /var/www/html" 
  cd /var/www/html	
fi

FILE=/etc/php.ini
if test -f "$FILE"; then
  echo "$FILE exists."
  sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 512M/g' /etc/php.ini
  sed -i 's/memory_limit = 128M/memory_limit = 4096M/g' /etc/php.ini
else
  echo "$FILE not exists."
  echo "upload_max_filesize = 512M" >> /etc/php.ini
  echo "memory_limit = 4096M" >> /etc/php.ini
fi

export magento_version='${magento_version}'
if [[ $magento_version == "latest" ]]; then
  magento_version=$(curl -s https://github.com/magento/magento2/releases/latest | grep -Po 'tag/\K.*' | cut -d'"' -f1)
  wget https://github.com/magento/magento2/archive/$magento_version.tar.gz
else
  wget https://github.com/magento/magento2/archive/refs/tags/$magento_version.tar.gz
fi  

if [[ $use_shared_storage == "true" ]]; then
  tar zxvf $magento_version.tar.gz --directory ${magento_shared_working_dir}
  cp -r ${magento_shared_working_dir}/magento2-$magento_version/* ${magento_shared_working_dir}
  rm -rf ${magento_shared_working_dir}/magento2-$magento_version
  rm -rf ${magento_shared_working_dir}/$magento_version.tar.gz
else
  tar zxvf $magento_version.tar.gz --directory /var/www/html
  cp -r /var/www/html/magento2-$magento_version/* /var/www/html
  rm -rf /var/www/html/magento2-$magento_version
  rm -rf /var/www/html/$magento_version.tar.gz
fi 

if [[ $use_shared_storage == "true" ]]; then
  echo "... Changing /etc/httpd/conf/httpd.conf with Document set to new shared NFS space ..."
  sed -i 's/"\/var\/www\/html"/"\${magento_shared_working_dir}"/g' /etc/httpd/conf/httpd.conf
  echo "... /etc/httpd/conf/httpd.conf with Document set to new shared NFS space ..."
  chown apache:apache -R ${magento_shared_working_dir}
  sed -i '/AllowOverride None/c\AllowOverride All' /etc/httpd/conf/httpd.conf
  chown apache:apache ${magento_shared_working_dir}/index.html
else
  chown apache:apache -R /var/www/html
  sed -i '/AllowOverride None/c\AllowOverride All' /etc/httpd/conf/httpd.conf
fi

cd /usr/local/bin
wget https://getcomposer.org/composer-1.phar
chmod +x composer-1.phar
mv composer-1.phar composer

if [[ $use_shared_storage == "true" ]]; then
  cd ${magento_shared_working_dir}   
else 
  cd /var/www/html
fi
/usr/local/bin/composer install

echo "Magento installed !"

echo "Configuring Magento..."

if [[ $use_shared_storage == "true" ]]; then
  #${magento_shared_working_dir}/bin/magento module:disable {Magento_Elasticsearch,Magento_Elasticsearch6,Magento_Elasticsearch7}
  ${magento_shared_working_dir}/bin/magento setup:install --no-ansi --db-host ${mds_ip}  --db-name ${magento_schema} --db-user ${magento_name} --db-password '${magento_password}' --admin-firstname='${magento_admin_firstname}' --admin-lastname='${magento_admin_lastname}' --admin-user='${magento_admin_login}' --admin-password='${magento_admin_password}' --admin-email='${magento_admin_email}'
  ${magento_shared_working_dir}/bin/magento config:set web/unsecure/base_url http://${public_ip}/
  ${magento_shared_working_dir}/bin/magento config:set web/secure/base_url https://${public_ip}/
  ${magento_shared_working_dir}/bin/magento config:set web/secure/use_in_frontend 0
  ${magento_shared_working_dir}/bin/magento config:set web/secure/use_in_adminhtml 0
  ${magento_shared_working_dir}/bin/magento config:set web/cookie/cookie_httponly 0 
  ${magento_shared_working_dir}/bin/magento setup:config:set --backend-frontname="${magento_backend_frontname}" --no-interaction  
  
  if [[ $use_redis_cache == "true" ]]; then
      if [[ $use_redis_as_cache_backend == "true" ]]; then
          ${magento_shared_working_dir}/bin/magento setup:config:set --cache-backend=redis --cache-backend-redis-server=${redis_ip_address} --cache-backend-redis-db=${redis_database} --cache-backend-redis-port=${redis_port} --cache-backend-redis-password=${redis_password} --no-interaction
      fi
      if [[ $use_redis_as_page_cache == "true" ]]; then
          ${magento_shared_working_dir}/bin/magento setup:config:set --page-cache=redis --page-cache-redis-server=${redis_ip_address} --page-cache-redis-db=${redis_database} --page-cache-redis-port=${redis_port} --page-cache-redis-password=${redis_password} --no-interaction 
      fi
  else
      sed -i "s/'save' => 'files'/'save' => 'files', 'save_path' => '\${magento_shared_working_dir}\/var\/session\/'/g" ${magento_shared_working_dir}/app/etc/env.php
  fi
  if [[ $install_sample_data == "true" ]]; then
     ${magento_shared_working_dir}/bin/magento sampledata:deploy --no-interaction
  fi
  cp /home/opc/index.html ${magento_shared_working_dir}/index.html
  rm /home/opc/index.html
  rm -rf ${magento_shared_working_dir}/var/cache/*
  chown apache:apache -R ${magento_shared_working_dir}
else 
  #/var/www/html/bin/magento module:disable {Magento_Elasticsearch,Magento_Elasticsearch6,Magento_Elasticsearch7}
  /var/www/html/bin/magento setup:install --no-ansi --db-host ${mds_ip}  --db-name ${magento_schema} --db-user ${magento_name} --db-password '${magento_password}' --admin-firstname='${magento_admin_firstname}' --admin-lastname='${magento_admin_lastname}' --admin-user='${magento_admin_login}' --admin-password='${magento_admin_password}' --admin-email='${magento_admin_email}'
  /var/www/html/bin/magento config:set web/unsecure/base_url http://${public_ip}/
  /var/www/html/bin/magento config:set web/secure/base_url https://${public_ip}/
  /var/www/html/bin/magento config:set web/secure/use_in_frontend 0
  /var/www/html/bin/magento config:set web/secure/use_in_adminhtml 0 
  /var/www/html/bin/magento config:set web/cookie/cookie_httponly 0 
  /var/www/html/bin/magento setup:config:set --backend-frontname="${magento_backend_frontname}" --no-interaction
  
  if [[ $use_redis_cache == "true" ]]; then
      if [[ $use_redis_as_cache_backend == "true" ]]; then
          /var/www/html/bin/magento setup:config:set --cache-backend=redis --cache-backend-redis-server=${redis_ip_address} --cache-backend-redis-db=${redis_database} --cache-backend-redis-port=${redis_port} --cache-backend-redis-password=${redis_password} --no-interaction
      fi  
      if [[ $use_redis_as_page_cache == "true" ]]; then
          /var/www/html/bin/magento setup:config:set --page-cache=redis --page-cache-redis-server=${redis_ip_address} --page-cache-redis-db=${redis_database} --page-cache-redis-port=${redis_port} --page-cache-redis-password=${redis_password} --no-interaction 
      fi
  fi 
  if [[ $install_sample_data == "true" ]]; then
     /var/www/html/bin/magento sampledata:deploy --no-interaction
  fi
  rm -rf /var/www/html/var/cache/*
  chown apache:apache -R /var/www/html
fi

echo "Magento configured!"

systemctl start httpd
systemctl enable httpd

echo "Magento deployed and Apache started !"