# Manual Kafka setup (learning path)

> The repo now provisions Kafka and Zookeeper automatically via cloud-init (see `cloud-init/kafka-bootstrap.yaml.tftpl`). This guide is preserved for **learning** — it walks through the same steps by hand so you can see what the automation does and how to reproduce it on any RHEL host.

You can follow this guide on:

- the VM created by `terraform apply` (just disable the automation first — temporarily remove the `custom_data` argument in `vm.tf`), or
- any fresh RHEL 9 host that has `java-11-openjdk-devel`, `git`, and `wget` installed.

> Solace connector 3.3.0 is compiled for Java 11 (`class file version 55`), so Java 8 is not sufficient even though Kafka 2.3.0 can run on Java 8.

---

## 1. Install Apache Kafka 2.3.0

```bash
sudo wget https://archive.apache.org/dist/kafka/2.3.0/kafka_2.12-2.3.0.tgz -O /opt/kafka_2.12-2.3.0.tgz
cd /opt
sudo tar -xvf kafka_2.12-2.3.0.tgz
sudo ln -s /opt/kafka_2.12-2.3.0 /opt/kafka
sudo chown -R kafkaAdmin:kafkaAdmin /opt/kafka*
sudo rm /opt/*.tgz
```

## 2. Create the Zookeeper systemd unit

`/etc/systemd/system/zookeeper.service`:

```ini
[Unit]
Description=zookeeper
After=syslog.target network.target

[Service]
Type=simple
User=kafkaAdmin
Group=kafkaAdmin
ExecStart=/opt/kafka/bin/zookeeper-server-start.sh /opt/kafka/config/zookeeper.properties
ExecStop=/opt/kafka/bin/zookeeper-server-stop.sh

[Install]
WantedBy=multi-user.target
```

## 3. Create the Kafka systemd unit

`/etc/systemd/system/kafka.service`:

```ini
[Unit]
Description=Apache Kafka
Requires=zookeeper.service
After=zookeeper.service

[Service]
Type=simple
User=kafkaAdmin
Group=kafkaAdmin
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh

[Install]
WantedBy=multi-user.target
```

## 4. Reload systemd and start the services

```bash
sudo systemctl daemon-reload
sudo systemctl start zookeeper
sudo systemctl start kafka
sudo systemctl status zookeeper.service
sudo systemctl status kafka.service
# start on boot
sudo systemctl enable zookeeper.service
sudo systemctl enable kafka.service
```

## 5. Open the Kafka port

```bash
sudo firewall-cmd --zone=public --add-port=9092/tcp --permanent
sudo firewall-cmd --reload
```

## 6. Put Kafka tools on PATH

```bash
echo 'export KAFKA_HOME=/opt/kafka' | sudo tee /etc/profile.d/kafka.sh
echo 'export PATH=$KAFKA_HOME/bin:$PATH' | sudo tee -a /etc/profile.d/kafka.sh
sudo chmod +x /etc/profile.d/kafka.sh
source /etc/profile.d/kafka.sh
```

---

## Verify everything is working

Run through the same checks the automation relies on:

```bash
systemctl is-active zookeeper
systemctl is-active kafka
ss -ltn | grep -E '(2181|9092)'
kafka-topics.sh --bootstrap-server localhost:9092 --list
```

If all four commands succeed, the manual bootstrap matches what cloud-init produces.

---

## Next steps

Continue with the Solace connector install and topic/consumer exercises in the main [README](../README.md#install-the-solace-pubsub-kafka-connector).
