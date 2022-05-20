#Cloning & Change Dir to clone_dir
.PHONY: start
start:
	git clone git@github.com:OpenVPN/easy-rsa.git

#Generating init-pki and Building CA and Sv&Cl key-pairs
.PHONY: build
build:
	make start
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa init-pki
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa build-ca nopass
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa build-server-full server nopass
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa build-client-full client1.domain.tld nopass
	cd easy-rsa/easyrsa3 && pwd && aws acm import-certificate --certificate fileb://pki/issued/server.crt --private-key fileb://pki/private/server.key --certificate-chain fileb://pki/ca.crt > arnmemo.txt

#Sending private-key and certificate to aws account manager
.PHONY: send
send:
	make build
	make clean

#Cleaning directory after generating key
.PHONY: clean
clean: 
	cd easy-rsa/easyrsa3 && pwd && rm -rf pki

#Deleting all server-side certificate in aws with this key not yet how to do...
.PHONY: delete_acm
delete1:
	aws acm list-certificates
#.PHONY: delete2
#delete2:
#	aws acm delete-certificate --certificate-arn $(shell sed -l 84 $(

#Building Clinent-VPN Endpoint in aws


