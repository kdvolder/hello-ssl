#!/bin/bash

set -e

# Source material for many of these commands: 
# https://tldp.org/HOWTO/SSL-Certificates-HOWTO/

mkdir workdir # create a working dir, makes it easier to delete all that stuff
cd workdir

# Creating a root certificate
mkdir -p private # place to keep our private key
openssl req -config /etc/ssl/openssl.cnf -nodes \
	-subj "/C=CA/O=Test/CN=Test_RootCert/" \
	-new -x509 -keyout private/cakey.pem -out cacert.crt -days 3650

# Add root certificate to chrome. 
# This is a manual process. Search for certificates in settings page. Add the 'cacert.crt' as a 'Authority'.

# The steps above only need to be done one time. The root certificate and private key can be re-used
# To sign different ssl certificates to be used for different domains. 

# The commands below create a ssl certificate and private key for a website on a given domain.
# The example below is setup to create certificate for 'localhost'.

export domain=localhost

# create certificate request for ssl website at ${domain}
openssl req -config /etc/ssl/openssl.cnf -nodes -new -subj "/C=CA/CN=${domain}" \
                  -newkey rsa:2048 -keyout ${domain}.key -out ${domain}.req

# sign the request using the ca
#   We need SAN but signing doesn't copy it from request without heavy hoop jumping.
#   Seems the 'easiest' solution is to put SAN into a separate config file to be passed to signing command...
# Note: multple DNS:... entries can be added as comma separated list.
echo "subjectAltName = DNS:${domain}" > ${domain}-openssl-ext.cnf
openssl x509 -extfile ${domain}-openssl-ext.cnf \
    -req -in ${domain}.req -CA cacert.crt -CAkey private/cakey.pem -CAcreateserial -out ${domain}.crt -days 5000 -sha256

#Inspect the crt as readable text
openssl x509 -in ${domain}.crt -noout -text

# create pks12 keystore with the data
cat ${domain}.key ${domain}.crt > ${domain}.pem
openssl pkcs12 -password pass:password -export -in ${domain}.pem -out ${domain}.keystore.p12

# list contents of keystore (commented out because it asks for password, run that thing manually to inspect the keystore.
keytool -list -v -storepass password -keystore ${domain}.keystore.p12

# place keystore in classpath where the sample project expects it
cp *.p12 ../../src/main/resources
