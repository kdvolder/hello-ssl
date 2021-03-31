Simple Boot App with proper SSL
===============================

Enabling SSL in spring-boot is relatively easy. The hardest part is not the 
enabling in boot or configuring the app, but creating or obtaining SSL certificates.

In this boot app we explore how to do that so that we can have a working boot
app setup running SSL on localhost.

Most (if not all) tutorials I have seen so far invariably end up making this work by using
self-signed certificates and then telling the https client somehow to disable
security. This allows those tutorials / examples to get away with using 
certificates that are actually not properly constructed.

In this example we are also going to use self-signed certificates. But we will *not* 
disable security. Instead we want to insure that the certificates are created/formatted 
properly; and configure/instruct clients (such as google chrome and curl)
to accept our self-signed root certificate.

TLDR; See `scripts/create-certificates.sh` for the steps/commands
involved in creating certificates.

Longer explanation now follows.

Create Root Certificate
=======================

The root certificate is a so called 'self-signed' certificate. The root certificate
represents a 'trusted authority'. The root certificate is used to sign other certificates.
Because we trust the 'authority' represented by the root, it follows that we trust the 
information in the certificates signed indirectly by the Root. This creates a 'chain of trust'
allowing a web client such as a browser verifies SSL certificates by essentially doing two things:

- check that the certificate matches the domain name of the website
- check that the certificate is signed (indirectly) by a trusted autority.

Normally, you would obtain a certificate from an official source (i.e. a trusted authority
such as Verisign, GoDaddy etc.). However for testing purposes, we will create our own 'root certificate'. Later on to make things work we will have to somehow configure the various clients (e.g. curl or chrome to let them know it is okay to accept our own root certificate
as a trusted authority.

Command:

```
openssl req -config /etc/ssl/openssl.cnf -nodes \
	-subj "/C=CA/O=Test/CN=Test_RootCert/" \
	-new -x509 -keyout private/cakey.pem -out cacert.crt -days 3650
```

What this does:

- create a signing request.
- store the private key in a file at private/cakey.pem
- `-nodes` disables DES password protection that would normally be used to protect the private key. (Not a good idea in a production of course, but convenient here)
- create a self-signed 'x509' certificate for the request (using the private key to sign it).
- store the publically visible component of the certificate into file `cacert.crt`
- make the certificate valid for 3650 days (10 years).

Create a Certificate for our Website
=====================================

Web servers need the ability to prove who they say they are. In a realistic setting they do not use self-signed certificates for this purpose.
Instead they obtain a certificate and a private signing key from a trusted authority. 

The certificate is specific to one or more DNS domain names. So a certificate created for one a domain 'foo.com' can only be used for that domain. The signing key allows the web server to create a cryptograhpic signature that 'proves' to clients that the certificate indeed belongs to them. (How exactly this works is not relevant, but only whoever is in possession of the private key can prove that the certificate is really 'theirs').

In the next step we will create the two bits of information that a CA would provide to a website owner. 

Command:

```
export domain=localhost
```

We'll use 'localhost' for testing. So naturally we will create a certificate specific to that domain. To make the rest of these instructions a bit more generic, we define the domain as a shell variable, So, you can substitute another domain name in its place.

Next we create the two pieces of information a web server needs to serve http traffic. This is done in two steps.


Step 1 is creating a 'signing request' and a private key. 

Command:

```
openssl req -config /etc/ssl/openssl.cnf -nodes -new -subj "/C=CA/CN=${domain}" \
                  -newkey rsa:2048 -keyout ${domain}.key -out ${domain}.req
```

- the private signing key is written to a file `${domain.key}`.
- the signing request is written to `${domain.req}`.

Step 2 is to submit the request to the CA to get a signed certificate. The certificate needs to be signed by the CA using the CA's private key.
This signature validates that CA has verified the owner of the private key indeed owns the domain names that the certificate
is valid for.

Command(s):

```
echo "subjectAltName = DNS:${domain}" > ${domain}-openssl-ext.cnf
openssl x509 -extfile ${domain}-openssl-ext.cnf \
    -req -in ${domain}.req -CA cacert.crt -CAkey private/cakey.pem -CAcreateserial -out ${domain}.crt -days 5000 -sha256
```

These commands:

- prepare 'subjectAltName' in a separate conf file. Conceptually you can think of this as part of the 'signing' request. But
  for technical reasons it must be supplied in a separate configuration file.
- Create a signed x509 certificate by signing the request using the CA root certificate and CA private key.


After running these two commands, we now have the two bits of information that the webserver needs. They are in two separate files:

- `${domain}.key`: the private key created in step 1. This is secret information only the webserver owner should know.
- `${domain}.crt`: the 'public' certificate that is paired with the private key.

Packaging the certificate and key
=================================

Although indeed web server just needs the info in the `${domain}.key`, `${domain}.key` they are not in a format that
a typical web-server / boot-app can consume as is. So we have to repackage these into a keystore. There are many keystore formats.
A common / recommended format to use is `pkcs12`. 

Commands:

```
cat ${domain}.key ${domain}.crt > ${domain}.pem
openssl pkcs12 -password pass:password -export -in ${domain}.pem -out ${domain}.keystore.p12
```

First command simply appends the private key and public certificate into a single file.
The second command creates pks12 store in a file at `${domain}.keystore.p12` secured by the password `password` and 
puts this public/private key pair into the store.

You can inspect the contents of the store like so:

```
keytool -list -v -storepass password -keystore ${domain}.keystore.p12
```

You should see something like:

```
Keystore type: PKCS12
Keystore provider: SUN

Your keystore contains 1 entry

Alias name: 1
Creation date: Mar. 31, 2021
Entry type: PrivateKeyEntry
Certificate chain length: 1
Certificate[1]:
Owner: CN=localhost, C=CA
Issuer: CN=Test_RootCert, O=Test, C=CA
Serial number: 6706b3bd6847d62596bfb71c9df74f2e95beec3c
Valid from: Wed Mar 31 14:42:26 PDT 2021 until: Fri Dec 08 13:42:26 PST 2034
Certificate fingerprints:
         SHA1: 1B:26:B5:03:76:35:33:4D:58:BB:37:F2:60:B5:4D:9B:69:21:37:BE
         SHA256: 3B:21:AD:8B:7A:9A:F5:C1:D5:E1:59:A5:C7:07:AE:FB:25:33:B9:96:D0:66:5D:61:6B:34:49:EB:2F:02:4D:07
Signature algorithm name: SHA256withRSA
Subject Public Key Algorithm: 2048-bit RSA key
Version: 3

Extensions: 

#1: ObjectId: 2.5.29.17 Criticality=false
SubjectAlternativeName [
  DNSName: localhost
]
```

Note the following interesting bits of information:

```
Alias name: 1
...
SubjectAlternativeName [
  DNSName: localhost
]
```

We'll need the 'Alias name' later. The `SubjectAlternativeName` makes the certificate specific to a given DNS name. Clients
will verify this and so the certificate is only good for a web server running on localhost (which is fine for testing :-).


Configuring the Boot App
========================

We now have everything needed to enable SSL in our boot app. The rest is simple. 

First we place the keystore file in our 'src/main/resources' directory. (There are other ways to make this file
available to the boot app at runtime, but this is the easiest).


Then we put this into our `application.yml` file to enable SSL and point the web server at the keystore file.

```
server:
  ssl:
    enabled: true
    key-alias: 1
    key-store: classpath:localhost.keystore.p12
    key-store-password: password
    key-store-type: PKCS12
```

When you run the boot app now. It will serve `https` traffic on `https://localhost:8080`.

Note that if you access this url from a browser, it will reject it. With a complaint that the certificate cannot be verified. 
The reason for this is that it was not signed by a 'trusted authority'. To fix this you have to add our 'test root certificate'
to the (long) list of trusted authorities that comes preconfigured in the client and/or OS.

Sometimes you can add the certificate in your OS and it will then work with all clients. However, each client is a little different and
some may use their own built-in list of trusted certificates rather than the OS-wide list.

For some examples of what you may need to do:

Configuring Chrome to Trust our Root CA
=======================================

- Open settings
- Search for 'Certifictes'
- Under 'Security' find 'Manage Certificates'
- Select the 'Authorities' Tab.
- Click 'Import'
- Find our `cacert.crt` file and import it.

Now when you load the url again it should work without any errors/warnings because the https traffic is properly signed with a certificate that is validate via a 'trusted authority'.

Using Curl
==========

Similarly to Chrome, if you simply:

```
curl https://localhost:8080
```

You will get an error like:

```
curl: (60) SSL certificate problem: unable to get local issuer certificate
```

You can tell curl that we trust our own root CA:

```
$ curl --cacert cacert.crt https://localhost:8080
Hello from SSL
```
