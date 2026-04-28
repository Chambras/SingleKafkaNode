#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  exec sudo -E "$0" "$@"
fi

KAFKA_USER="${KAFKA_USER:-kafkaAdmin}"
KAFKA_VERSION="${KAFKA_VERSION:-2.3.0}"
SCALA_VERSION="${SCALA_VERSION:-2.12}"
JAVA_PACKAGE="${JAVA_PACKAGE:-java-11-openjdk-devel}"
KAFKA_PKG="kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
KAFKA_TGZ="/opt/${KAFKA_PKG}.tgz"
KAFKA_URL="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/${KAFKA_PKG}.tgz"

if ! id "${KAFKA_USER}" >/dev/null 2>&1; then
  echo "Kafka user '${KAFKA_USER}' does not exist. Set KAFKA_USER to the VM admin user." >&2
  exit 1
fi

yum install -y httpd "${JAVA_PACKAGE}" tmux git wget tar firewalld

cat >/var/www/html/index.html <<HTML
<!doctype html><html><body><h1>Hello ${KAFKA_USER} from Azure!</h1></body></html>
HTML

if [[ ! -d "/opt/${KAFKA_PKG}" ]]; then
  wget -q "${KAFKA_URL}" -O "${KAFKA_TGZ}"
  tar -xzf "${KAFKA_TGZ}" -C /opt
  rm -f "${KAFKA_TGZ}"
fi

ln -sfn "/opt/${KAFKA_PKG}" /opt/kafka
chown -R "${KAFKA_USER}:${KAFKA_USER}" "/opt/${KAFKA_PKG}" /opt/kafka

cat >/etc/systemd/system/zookeeper.service <<UNIT
[Unit]
Description=zookeeper
After=syslog.target network.target

[Service]
Type=simple
User=${KAFKA_USER}
Group=${KAFKA_USER}
ExecStart=/opt/kafka/bin/zookeeper-server-start.sh /opt/kafka/config/zookeeper.properties
ExecStop=/opt/kafka/bin/zookeeper-server-stop.sh

[Install]
WantedBy=multi-user.target
UNIT

cat >/etc/systemd/system/kafka.service <<UNIT
[Unit]
Description=Apache Kafka
Requires=zookeeper.service
After=zookeeper.service

[Service]
Type=simple
User=${KAFKA_USER}
Group=${KAFKA_USER}
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh

[Install]
WantedBy=multi-user.target
UNIT

cat >/etc/profile.d/kafka.sh <<'PROFILE'
export KAFKA_HOME=/opt/kafka
export PATH=$KAFKA_HOME/bin:$PATH
PROFILE
chmod 0755 /etc/profile.d/kafka.sh

systemctl enable --now httpd.service
systemctl daemon-reload
systemctl enable --now zookeeper.service
systemctl enable --now kafka.service
systemctl enable --now firewalld
firewall-cmd --zone=public --add-port=9092/tcp --permanent
firewall-cmd --reload

echo "Kafka ${KAFKA_VERSION} is installed at /opt/kafka and services are started."
