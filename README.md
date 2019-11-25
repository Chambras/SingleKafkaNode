# Single Kafka Node

Deploys a Sungle Kafka server in order to ingest SWIM data in real time.

## Pre-requists

It is assumed that you have azure CLI installed and configured.
More information on this topic [here](https://docs.microsoft.com/en-us/azure/terraform/terraform-overview).

### versions

* Terraform =>0.12.12
* Azure provider 1.36.1

## Usage

Just run these commands to initialize terraform, get a plan and approve it to apply it.

```ssh
terraform init
terraform plan
terraform apply
```

The terraform sctipt installs the following extra packages on the VM:

* java-1.8.0-openjdk-devel
* tmux
* git

Optional: It is recommended to install jq to parce JSON requests in the future

```ssh
wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x ./jq
sudo cp jq /usr/bin
```

## Kafka Installation and Configuration

ssh into the new VM once it is ready

```ssh
ssh kafkaAdmin@IP -i {{PATH/TO/SSHKEY}}
```

Get Apache Kafka version 2.3.0

```ssh
wget -q https://www-eu.apache.org/dist/kafka/2.3.0/kafka_2.12-2.3.0.tgz
tar -xzf kafka_2.12-2.3.0.tgz
```

Add kafka tools to path

```ssh
export KAFKA_HOME=~/kafka_2.12-2.3.0
export PATH=$KAFKA_HOME/bin:$PATH
```

Start Single Zookeeper node

```ssh
cd kafka_2.12-2.3.0/
zookeeper-server-start.sh config/zookeeper.properties
```

Start Single Kafka server

```ssh
cd kafka_2.12-2.3.0/
kafka-server-start.sh config/server.properties
```

## Build and Copy Solace connector using Gradle and its Dependencies

clone Solace connector source code from GitHub

```ssh
cd
git clone https://github.com/SolaceLabs/pubsubplus-connector-kafka-source.git
```

Check and Build Solace Connector

```ssh
# check gradle build
cd pubsubplus-connector-kafka-source
./gradlew clean check

# create new Solace Connector gradle build
./gradlew clean jar
```

copy Solace Connector to ~/kafka_2.12-2.3.0/libs/

```ssh
cp -v build/libs/*.jar ~/kafka_2.12-2.3.0/libs/
```

get the Java Solace depedencies

```ssh
cd ..
wget -q https://products.solace.com/download/JAVA_API -O sol-connector.zip
```

or from maven central

```ssh
wget https://repo1.maven.org/maven2/com/solacesystems/sol-jcsmp/10.6.3/sol-jcsmp-10.6.3.jar
```

unpack and copy dependencies to ~/kafka_2.12-2.3.0/libs/

```ssh
unzip sol-connector.zip
cp -v sol-jcsmp-*/lib/*.jar ~/kafka_2.12-2.3.0/libs/
```

## Manage Apache Kafka topics

Create a topic

```ssh
# stdds
kafka-topics.sh --create --replication-factor 3 --partitions 1 --topic stdds --zookeeper localhost:9092

#tfms
kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 1 --topic tfms
```

List topics

```ssh
kafka-topics.sh --list --bootstrap-server localhost:9092
```

Delete topics

```ssh
# stdds
kafka-topics.sh --delete --topic stdds --bootstrap-server localhost:9092

# tfms
kafka-topics.sh --delete --topic tfms --bootstrap-server localhost:9092
```

Describe topics

```ssh
# stdds
kafka-topics.sh --describe --topic tfms --bootstrap-server localhost:9092

# tfms
kafka-topics.sh --describe --topic tfms --bootstrap-server localhost:9092
```

## Configure Solace Connector to connect to SWIM Data Source

Update ~/kafka_2.12-2.3.0/config/connect-standalone.properties
set:

```vi
bootstrap.servers= localhost:9092

key.converter=org.apache.kafka.connect.storage.StringConverter
value.converter=org.apache.kafka.connect.storage.StringConverter
```

```ssh
vi ~/kafka_2.12-2.3.0/config/connect-standalone.properties
```

This is the final content of the file

```ssh
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# These are defaults. This file just demonstrates how to override some settings.
bootstrap.servers=localhost:9092

# The converters specify the format of data in Kafka and how to translate it into Connect data. Every Connect user will
# need to configure these based on the format they want their data in when loaded from or stored into Kafka
key.converter=org.apache.kafka.connect.storage.StringConverter
value.converter=org.apache.kafka.connect.storage.StringConverter
# Converter-specific settings can be passed in by prefixing the Converter's setting with the converter we want to apply
# it to
key.converter.schemas.enable=true
value.converter.schemas.enable=true

offset.storage.file.filename=/tmp/connect.offsets
# Flush much faster than normal, which is useful for testing/debugging
offset.flush.interval.ms=10000

# Set to a list of filesystem paths separated by commas (,) to enable class loading isolation for plugins
# (connectors, converters, transformations). The list should consist of top level directories that include
# any combination of:
# a) directories immediately containing jars with plugins and their dependencies
# b) uber-jars with plugins and their dependencies
# c) directories immediately containing the package directory structure of classes of plugins and their dependencies
# Note: symlinks will be followed to discover dependencies or plugins.
# Examples:
# plugin.path=/usr/local/share/java,/usr/local/share/kafka/plugins,/opt/connectors,
#plugin.path=
```

Create stdds and/or tfms config connectors

```ssh
# stdds
sudo vi ~/kafka_2.12-2.3.0/config/connect-solace-stdds-source.properties

# tfms
sudo vi ~/kafka_2.12-2.3.0/config/connect-solace-tfms-source.properties
```

> These values are mandatory and you need provide them:

```vi
name
kafka.topic
sol.host
sol.username
sol.password
sol.vpn_name
sol.queue
```

This is the final content of the file

```ssh
name={{connectoName}}
connector.class=com.solace.source.connector.SolaceSourceConnector
tasks.max=2
kafka.topic={{kafkaTopic}}
sol.host={{SWIMEndpoint:Port}}
sol.username={{SWIMUserNaMe}}
sol.password={{Password}}
sol.vpn_name={{SWIMVPN}}
sol.topics=soltest
sol.queue={{SWIMQueue}}
sol.message_callback_on_reactor=false
sol.message_processor_class=com.solace.source.connector.msgprocessors.SolaceSampleKeyedMessageProcessor
#sol.message_processor_class=com.solace.source.connector.msgprocessors.SolSampleSimpleMessageProcessor
sol.generate_send_timestamps=false
sol.generate_rcv_timestamps=false
sol.sub_ack_window_size=255
sol.generate_sequence_numbers=true
sol.calculate_message_expiration=true
sol.subscriber_dto_override=false
sol.channel_properties.connect_retries=-1
sol.channel_properties.reconnect_retries=-1
sol.kafka_message_key=DESTINATION
sol.ssl_validate_certificate=false
#sol.ssl_validate_certicate_date=false
#sol.ssl_connection_downgrade_to=PLAIN_TEXT
sol.ssl_trust_store=/opt/PKI/skeltonCA/heinz1.ts
sol.ssl_trust_store_pasword=sasquatch
sol.ssl_trust_store_format=JKS
#sol.ssl_trusted_command_name_list
sol.ssl_key_store=/opt/PKI/skeltonCA/heinz1.ks
sol.ssl_key_store_password=sasquatch
sol.ssl_key_store_format=JKS
sol.ssl_key_store_normalized_format=JKS
sol.ssl_private_key_alias=heinz1
sol.ssl_private_key_password=sasquatch
#sol.authentication_scheme=AUTHENTICATION_SCHEME_CLIENT_CERTIFICATE
key.converter.schemas.enable=true
value.converter.schemas.enable=true
#key.converter=org.apache.kafka.connect.converters.ByteArrayConverter
value.converter=org.apache.kafka.connect.converters.ByteArrayConverter
#key.converter=org.apache.kafka.connect.json.JsonConverter
#value.converter=org.apache.kafka.connect.json.JsonConverter
key.converter=org.apache.kafka.connect.storage.StringConverter
#value.converter=org.apache.kafka.connect.storage.StringConverter
```

Start  standalone connection

```ssh
# stdds
connect-standalone.sh ~/kafka_2.12-2.3.0/config/connect-standalone.properties ~/kafka_2.12-2.3.0/config/connect-solace-stdds-source.properties

# tfms
connect-standalone.sh ~/kafka_2.12-2.3.0/config/connect-standalone.properties ~/kafka_2.12-2.3.0/config/connect-solace-tfms-source.properties
```

Check incoming messages. This command will display all the messages from the beginning and might take some time if you have lots of messages.

```ssh
# stdds
kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic stdds --from-beginning

# tfms
kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic tfms --from-beginning
```

If you just want to check specific messages and not display all of them, you can use the --max-messages option.
The following comand will display the first message.

```ssh
# stdds
kafka-console-consumer.sh --from-beginning --max-messages 1 --topic stdds --bootstrap-server localhost:9092

# tfms
kafka-console-consumer.sh --from-beginning --max-messages 1 --topic tfms --bootstrap-server localhost:9092
```

if you want to see all available options just run the kafka-console-consumer.sh without any options

```ssh
kafka-console-consumer.sh
```

## Clean resources

It will destroy everything that was created.

```ssh
terraform destroy --force
```

## Caution

Be aware that by running this script your account might get billed.
Also it is recommended to use a remote state instead of a local one.

## Authors

* Marcelo Zambrana
