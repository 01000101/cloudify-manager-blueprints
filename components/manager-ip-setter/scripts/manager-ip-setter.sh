#! /usr/bin/env bash
set -e

function set_manager_ip() {

  ip=$(/usr/sbin/ip a s | /usr/bin/grep -oE 'inet [^/]+' | /usr/bin/cut -d' ' -f2 | /usr/bin/grep -v '^127.' | /usr/bin/grep -v '^169.254.' | /usr/bin/head -n1)

  echo "Setting manager IP to: ${ip}"

  echo "Updating cloudify-amqpinflux.."
  /usr/bin/sed -i -e "s/AMQP_HOST=.*/AMQP_HOST="'"'"${ip}"'"'"/" /etc/sysconfig/cloudify-amqpinflux
  /usr/bin/sed -i -e "s/INFLUXDB_HOST=.*/INFLUXDB_HOST="'"'"${ip}"'"'"/" /etc/sysconfig/cloudify-amqpinflux

  echo "Updating cloudify-riemann.."
  /usr/bin/sed -i -e "s/RABBITMQ_HOST=.*/RABBITMQ_HOST="'"'"${ip}"'"'"/" /etc/sysconfig/cloudify-riemann
  /usr/bin/sed -i -e "s/REST_HOST=.*/REST_HOST="'"'"${ip}"'"'"/" /etc/sysconfig/cloudify-riemann

  echo "Updating cloudify-mgmtworker.."
  /usr/bin/sed -i -e "s/REST_HOST=.*/REST_HOST="'"'"${ip}"'"'"/" /etc/sysconfig/cloudify-mgmtworker
  /usr/bin/sed -i -e "s/FILE_SERVER_HOST=.*/FILE_SERVER_HOST="'"'"${ip}"'"'"/" /etc/sysconfig/cloudify-mgmtworker
  /usr/bin/sed -i -e "s#MANAGER_FILE_SERVER_URL="'"'"http://.*:53229"'"'"#MANAGER_FILE_SERVER_URL="'"'"http://${ip}:53229"'"'"#" /etc/sysconfig/cloudify-mgmtworker
  /usr/bin/sed -i -e "s#MANAGER_FILE_SERVER_BLUEPRINTS_ROOT_URL="'"'"http://.*:53229/blueprints"'"'"#MANAGER_FILE_SERVER_BLUEPRINTS_ROOT_URL="'"'"http://${ip}:53229/blueprints"'"'"#" /etc/sysconfig/cloudify-mgmtworker
  /usr/bin/sed -i -e "s#MANAGER_FILE_SERVER_DEPLOYMENTS_ROOT_URL="'"'"http://.*:53229/deployments"'"'"#MANAGER_FILE_SERVER_DEPLOYMENTS_ROOT_URL="'"'"http://${ip}:53229/deployments"'"'"#" /etc/sysconfig/cloudify-mgmtworker

  echo "Updating broker_config.json.."
  /usr/bin/sed -i -e "s/"'"'"broker_hostname"'"'": "'"'".*"'"'"/"'"'"broker_hostname"'"'": "'"'"${ip}"'"'"/" /opt/mgmtworker/work/broker_config.json

  echo "Updating broker_ip in provider context.."
  /opt/cloudify/manager-ip-setter/update-provider-context.py ${ip}

  echo "Creating internal SSL certificates.."
  /opt/cfy/embedded/bin/python /opt/cloudify/manager-ip-setter/create-internal-ssl-certs.py ${ip}
  
  echo "Restarting nginx.."
  systemctl restart nginx

  echo "Done!"

}

touched_file_path="/opt/cloudify/manager-ip-setter/touched"

if [ ! -f ${touched_file_path} ]; then
  set_manager_ip
  touch ${touched_file_path}
else
  echo "${touched_file_path} exists - not setting manager ip."
fi
