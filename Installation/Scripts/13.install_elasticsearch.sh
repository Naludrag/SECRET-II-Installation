#!/bin/bash
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt-get install apt-transport-https -y
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list
# Install elastic
sudo apt-get update && sudo apt-get install elasticsearch -y
# Install logsatsh
sudo apt-get update && sudo apt-get install logstash -y

# Config logstash dans le fichier /etc/logsatsh/conf.d
sudo tee /etc/logstash/conf.d/tshark.conf > /dev/null << 'EOF'
input {
  tcp {
    port => 17570
  }
}

filter {
  # Ignore index lines
  if ([message] =~ "{\"index") {
    drop {}
  }

  # Use Json message parser and not codec
  json {
    source => "message"
  }

  date {
    match => [ "timestamp", "UNIX_MS" ]
  }

  mutate {
    # remove the original json
    remove_field => [ "json", "message" ]
  }
}

output {  
  elasticsearch {
    index => "freshinstall"
    hosts => ["http://localhost:9200"]
  }
} 

EOF