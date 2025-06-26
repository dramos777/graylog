# Graylog
Graylog is a powerful Security Information and Event Management (SIEM) solution offering a robust log analytics platform that simplifies the collection, search, analysis, and alerting of all types of machine-generated data. It is specifically designed to capture data from diverse sources, allowing you to centralize, secure, and monitor your log data efficiently 
- Site oficial: https://graylog.org/
- Compose do projeto: https://github.com/Graylog2/docker-compose

Installation and Configuration:
```
apt update && apt install vim wget curl git -y
```
Configuration of sysctl.conf as per the official documentation:
```
sudo echo “vm.max_map_count=262144” >> /etc/sysctl.conf
sudo sysctl -p
```
Clone the project and configure the secret and hash:
```
git clone https://github.com/Graylog2/docker-compose.git
mv docker-compose/cluster/{*,.env*} .
rm -rf docker-compose
cp .env.example .env

# Install necessary packages to generate secret/hash
sudo apt update && apt install pwgen -y
# Generate the secret
pwgen -N 1 -s 96
# Generate the hash
echo -n yourpassword | shasum -a 256
```
The lines GRAYLOG_PASSWORD_SECRET="" and GRAYLOG_ROOT_PASSWORD_SHA2="" in the .env file must be updated with the generated secret and hash:
```
# Replace yourSecreteGenerateBypwgen with the generated secret
sed -i 's/GRAYLOG_PASSWORD_SECRET=\"\"/GRAYLOG_PASSWORD_SECRET=\"yourSecreteGenerateBypwgen\"/g' .env

# Replace yourHashGenerateByshasum with your generated hash
sed -i 's/GRAYLOG_ROOT_PASSWORD_SHA2=\"\"/GRAYLOG_ROOT_PASSWORD_SHA2=\"yourHashGenerateByshasum\"/g' .env
```

Finally, start the containers with compose and list them:
```
docker compose up -d
docker container ls
```
## Troubleshooting
Remove deflector
```
# In the web interface, look up the deflector index and then delete it
curl -XDELETE http://localhost:9200/gl-system-events_deflector
```

### Maintainer

Emanuel Dramos

- Github: https://github.com/dramos777


