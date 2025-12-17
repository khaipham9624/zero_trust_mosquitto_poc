cd $HOME
rm -rf broker/ ca.d/  myCA/ publisher/ server/ subcriber/



        #    ROOTCA
        #     / \
        # Client Server
 

# Set up root CA
mkdir -p $HOME/myCA/rootCA 
cd $HOME/myCA/rootCA 
mkdir private cert issued_certs crl csr data ocsp-certs
openssl rand -hex -out private/.rand 16
touch data/index.txt 
openssl rand -hex -out data/serial.txt 8 
echo "1000" > data/crl_number
# touch rootCA.conf
# vim rootCA.conf
cp $HOME/rootCA.conf $HOME/myCA/rootCA 

## Generate self-signed rootCA certificate
openssl genrsa -out private/rootCA.key 2048
openssl req -config rootCA.conf -new -x509 -nodes -days 3650 -keyout private/rootCA.key -sha256 -out cert/rootCA.crt \
-subj '/CN=rootCA/O=TMA Solutions/OU=AOS/C=VN/L=Ho Chi Minh city/ST=Tan Binh district' \
-extensions v3_ca

### generate CRLs
openssl ca -batch -gencrl -out crl/rootCA.crl -config rootCA.conf

# ### Generate rootCA OCSP certificate
# openssl req -new -nodes -keyout ./ocsp-certs/ocsp.key -out ./csr/ocsp.csr -config rootCA.conf \
# -subj '/CN=rootCA_OCSP/O=TMA Solutions/OU=AOS/C=VN/L=Ho Chi Minh city/ST=Tan Binh district'
# openssl ca -batch -config rootCA.conf  -out ./ocsp-certs/ocsp.crt -extensions v3_OCSP -infiles ./csr/ocsp.csr

# # Launch OCSP servers
# cd $HOME/myCA/rootCA
# openssl ocsp -index data/index.txt -port 49210 -rsigner ocsp-certs/ocsp.crt \
# -rkey ocsp-certs/ocsp.key -CA cert/rootCA.crt




# Generating Server Certificate signed by root CA
mkdir $HOME/server
cd $HOME/server
openssl genrsa -out server.key 2048
openssl req -new -sha256 -nodes -key server.key -out server.csr \
-subj '/CN=server/O=TMA Solutions/OU=AOS/C=VN/L=Ho Chi Minh city/ST=Phu Nhuan district'
openssl ca -batch -config $HOME/myCA/rootCA/rootCA.conf  -out server.crt -extensions server_cert -infiles server.csr
cat server.crt > server_bundle.pem

# Generating broker Certificate signed by root CA
mkdir $HOME/broker
cd $HOME/broker
openssl genrsa -out broker.key 2048
openssl req -new -sha256 -nodes -key broker.key -out broker.csr \
-subj '/CN=localhost/O=TMA Solutions/OU=AOS/C=VN/L=Ho Chi Minh city/ST=Phu Nhuan district'
openssl ca -batch -config $HOME/myCA/rootCA/rootCA.conf  -out broker.crt -extensions server_cert -infiles broker.csr

# Generating subcriber Certificate signed by root CA
mkdir $HOME/subcriber
cd $HOME/subcriber
openssl genrsa -out subcriber.key 2048
openssl req -new -sha256 -nodes -key subcriber.key -out subcriber.csr \
-subj '/CN=subcriber/O=TMA Solutions/OU=AOS/C=VN/L=Ho Chi Minh city/ST=Phu Nhuan district'
openssl ca -batch -config $HOME/myCA/rootCA/rootCA.conf  -out subcriber.crt -extensions user_cert -infiles subcriber.csr

# Generating publisher Certificate signed by root CA
mkdir $HOME/publisher
cd $HOME/publisher
openssl genrsa -out publisher.key 2048
openssl req -new -sha256 -nodes -key publisher.key -out publisher.csr \
-subj '/CN=publisher/O=TMA Solutions/OU=AOS/C=VN/L=Ho Chi Minh city/ST=Phu Nhuan district'
openssl ca -batch -config $HOME/myCA/rootCA/rootCA.conf  -out publisher.crt -extensions user_cert -infiles publisher.csr



mkdir $HOME/ca.d
cd $HOME/ca.d
cp $HOME/myCA/rootCA/cert/rootCA.crt $HOME/ca.d
cp $HOME/myCA/rootCA/crl/rootCA.crl $HOME/ca.d
openssl rehash .
# ln -sf rootCA.crt `openssl x509 -hash -in rootCA.crt -noout`.0



## Revoke server certificate
### backup
cd $HOME/myCA/rootCA
cp -r crl crl.bk
cp -r data data.bk
### Revoke certificates
cd $HOME/myCA/rootCA
openssl ca -batch -revoke $HOME/server/server.crt -config rootCA.conf
openssl ca -batch -gencrl -out crl/rootCA.crl -config rootCA.conf




mkdir $HOME/crl_dir
cp $HOME/myCA/rootCA/crl/rootCA.crl $HOME/crl_dir



# Link cert and crl
ln -sf rootCA.crt `openssl x509 -hash -in rootCA.crt -noout`.0
ln -sf rootCA.crl `openssl crl -hash -fingerprint -noout -in rootCA.crl |grep -oP 'issuer name hash=\K\w+'`.r0



openssl s_server     -accept 8443     -cert server.crt     -key server.key     -Verify 1     -CApath ~/ca.d/
openssl s_client     -connect 127.0.0.1:8443     -cert myCliCert.pem     -key myCliPrivate.key     -CApath ~/ca.d/











 
# # Generating Server Certificate signed by root CA
# mkdir $HOME/subcriber
# cd $HOME/subcriber
# openssl genrsa -out subcriber.key 2048
# openssl req -new -sha256 -nodes -key subcriber.key -out subcriber.csr \
# -subj '/CN=subcriber/O=TMA Solutions/OU=AOS/C=VN/L=Ho Chi Minh city/ST=Phu Nhuan district'
# openssl ca -batch -config $HOME/myCA/rootCA/rootCA.conf  -out subcriber.crt -extensions user_cert -infiles subcriber.csr


# # Generating Server Certificate signed by root CA
# mkdir $HOME/publisher
# cd $HOME/publisher
# openssl genrsa -out publisher.key 2048
# openssl req -new -sha256 -nodes -key publisher.key -out publisher.csr \
# -subj '/CN=publisher/O=TMA Solutions/OU=AOS/C=VN/L=Ho Chi Minh city/ST=Phu Nhuan district'
# openssl ca -batch -config $HOME/myCA/rootCA/rootCA.conf  -out publisher.crt -extensions user_cert -infiles publisher.csr



# # Generating Server Certificate signed by root CA
# mkdir $HOME/broker
# cd $HOME/broker
# openssl genrsa -out broker.key 2048
# openssl req -new -sha256 -nodes -key broker.key -out broker.csr \
# -subj '/CN=localhost/O=TMA Solutions/OU=AOS/C=VN/L=Ho Chi Minh city/ST=Phu Nhuan district'
# openssl ca -batch -config $HOME/myCA/rootCA/rootCA.conf  -out broker.crt -extensions server_cert -infiles broker.csr



mkdir $HOME/ca.d
cd $HOME/ca.d
cp $HOME/myCA/rootCA/cert/rootCA.crt $HOME/ca.d
ln -sf rootCA.crt `openssl x509 -hash -in rootCA.crt -noout`.0


