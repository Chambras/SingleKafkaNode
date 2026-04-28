# Kafka bootstrap options

This repo keeps **cloud-init as the default supported deployment path** while also showing two equivalent learning paths: a standalone shell script and an Ansible playbook.

All three approaches configure the same single-node development runtime:

- packages: `httpd`, Java 11, `tmux`, `git`, `wget`, `tar`, `firewalld`
- Apache Kafka 2.3.0 with Scala 2.12 under `/opt/kafka`
- `zookeeper.service` and `kafka.service`
- TCP `9092` opened in `firewalld`
- Kafka tools on `PATH` through `/etc/profile.d/kafka.sh`

## Comparison

| Option | Location | When to use | Tradeoff |
| --- | --- | --- | --- |
| Cloud-init | `cloud-init/kafka-bootstrap.yaml.tftpl` | Default Terraform deployment. The VM configures itself on first boot. | Best automation path, but cloud-init logs can be harder to debug. |
| Standalone shell script | `scripts/install-kafka.sh` | Manual learning, troubleshooting, or rebuilding Kafka on an existing VM. | Easy to read and run, but less declarative than Ansible. |
| Ansible playbook | `ansible/playbook.yml` | Demonstrating configuration management after the VM exists. | Reusable and idempotent, but requires Ansible on the operator machine. |

## Option 1: cloud-init (default)

Terraform renders the cloud-init template into `azurerm_linux_virtual_machine.custom_data`:

```hcl
custom_data = base64encode(templatefile("${path.module}/cloud-init/kafka-bootstrap.yaml.tftpl", {
  vm_user       = var.vmUserName
  java_package  = var.javaPackage
  kafka_version = var.kafkaVersion
  scala_version = var.kafkaScalaVersion
}))
```

Use this path for normal deployments:

```bash
terraform init
terraform apply
```

If first boot is still running, inspect cloud-init:

```bash
sudo tail -f /var/log/cloud-init-output.log
```

## Option 2: standalone shell script

Use the script when you want to see the imperative steps or repair an existing VM.

From your local machine:

```bash
scp -i ~/.ssh/vm_ssh scripts/install-kafka.sh kafkaAdmin@<kafkaPublicIP>:/tmp/install-kafka.sh
ssh -i ~/.ssh/vm_ssh kafkaAdmin@<kafkaPublicIP>
sudo bash /tmp/install-kafka.sh
```

Override defaults with environment variables:

```bash
sudo KAFKA_USER=kafkaAdmin \
  KAFKA_VERSION=2.3.0 \
  SCALA_VERSION=2.12 \
  JAVA_PACKAGE=java-11-openjdk-devel \
  bash /tmp/install-kafka.sh
```

## Option 3: Ansible playbook

Use Ansible after Terraform creates the VM and you can SSH to it.

Install Ansible locally if needed:

```bash
python3 -m pip install --user ansible
```

Create an inventory from the example:

```bash
cp ansible/inventory.example.ini ansible/inventory.ini
$EDITOR ansible/inventory.ini
```

Run the playbook:

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

Override defaults at runtime:

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml \
  -e kafka_user=kafkaAdmin \
  -e kafka_version=2.3.0 \
  -e kafka_scala_version=2.12 \
  -e kafka_java_package=java-11-openjdk-devel
```

## Verify any bootstrap path

SSH to the VM and run:

```bash
systemctl is-active zookeeper
systemctl is-active kafka
ss -ltn | grep -E '(2181|9092)'
kafka-topics.sh --bootstrap-server localhost:9092 --list
java -version
```

Java should report version 11 or newer for the Solace PubSub+ Kafka source connector 3.3.0.

