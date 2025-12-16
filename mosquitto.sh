sudo apt install mosquitto mosquitto-dev
sudo apt install build-essential
sudo apt install libmosquitto-dev
sudo apt install libcurl4-openssl-dev
sudo apt install libjson-c-dev

# Start broker
# sudo systemctl status mosquitto
# sudo systemctl start mosquitto
sudo systemctl stop mosquitto
mosquitto -v

# Subcriber
mosquitto_sub -h localhost -t "test/topic" -v
mosquitto_pub -l -t test/topic # test entering multiple messages

# Publisher
mosquitto_pub -h localhost -t "test/topic" -m "Hello MQTT!"


# /etc/mosquitto/conf.d/ssl.conf
listener 8883
protocol mqtt
cafile /home/pqkhai/ca.d/rootCA.crt
certfile /home/pqkhai/broker/broker.crt
keyfile /home/pqkhai/broker/broker.key

require_certificate true
use_identity_as_username true




mosquitto_sub -h localhost -p 8883 -t "secure/#" -v \
  --cafile /home/pqkhai/ca.d/rootCA.crt \
  --cert /home/pqkhai/subcriber/subcriber.crt \
  --key /home/pqkhai/subcriber/subcriber.key


mosquitto_pub -h localhost -p 8883 -t "secure/test" -m "hello mTLS" \
  --cafile /home/pqkhai/ca.d/rootCA.crt \
  --cert /home/pqkhai/publisher/publisher.crt \
  --key /home/pqkhai/publisher/publisher.key



sudo mkdir -p /usr/lib/mosquitto/plugins

make
sudo cp /home/pqkhai/code/zero_trust_mosquitto_poc/plugin.so /usr/lib/mosquitto/plugins/
sudo chown mosquitto:mosquitto /usr/lib/mosquitto/plugins/plugin.so
sudo mosquitto -c /etc/mosquitto/mosquitto.conf -v

python3 pdp_server.py
sudo tail -F /var/log/mosquitto/mosquitto.log
mosquitto_sub -h localhost -t "#" -v
mosquitto_pub -l -t device/1/tx -i 1

cat /etc/mosquitto/mosquitto.conf
    # Place your local configuration in /etc/mosquitto/conf.d/
    #
    # A full description of the configuration file is at
    # /usr/share/doc/mosquitto/examples/mosquitto.conf.example

    persistence true
    persistence_location /var/lib/mosquitto/

    log_dest file /var/log/mosquitto/mosquitto.log
    plugin /usr/lib/mosquitto/plugins/plugin.so
    plugin_opt_config_path .
    allow_anonymous true


    include_dir /etc/mosquitto/conf.d

