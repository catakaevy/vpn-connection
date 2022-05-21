#Cloning & Change Dir to clone_dir
.PHONY: start
start:
	git clone git@github.com:OpenVPN/easy-rsa.git

#Region Check
.PHONY: region
region: 
	aws ec2 describe-regions

#Generating init-pki and Building CA and Sv&Cl key-pairs | if you want to change the region, use this "export AWS_DEFAULT_REGION=us-west-2"
.PHONY: build
build:
	make start
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa init-pki
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa build-ca nopass
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa build-server-full server nopass
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa build-client-full client1.domain.tld nopass
	cd easy-rsa/easyrsa3 && pwd && aws acm import-certificate --certificate fileb://pki/issued/server.crt --private-key fileb://pki/private/server.key --certificate-chain fileb://pki/ca.crt > arnmemo.json
	pwd && python3 arn_catch.py

#Cleaning directory after generating key
.PHONY: clean
clean: 
	cd easy-rsa/easyrsa3 && pwd && rm -rf pki

#Deleting server-side certificate that you created here in aws with this key
.PHONY: delete_acm
delete_acm:
	aws acm delete-certificate --certificate-arn $(shell cat arn.txt)

#Building Clinent-VPN Endpoint in aws
.PHONY: endpoint
endpoint:
	aws ec2 create-client-vpn-endpoint \
		--client-cidr-block $(CIDR_BLK) \
		--server-certificate-arn $(shell cat arn.txt) \
		--authentication-options Type=certificate-authentication,MutualAuthentication={ClientRootCertificateChainArn=$(shell cat arn.txt)} \
		--connection-log-options Enabled=false

#Moving downloaded-client-config.ovpn to the right directory
.PHONY: mv_set
mv_set:
	mv $(DOWNLOAD_PATH)/downloaded-client-config.ovpn .

#cert $(VPN_CONNETION_PATH)/easy-rsa/easyrsa3/pki/issued/client1.domain.tld.crt
#key $(VPN_CONNETION_PATH)/easy-rsa/easyrsa3/pki/private/client1.domain.tld.key

#/Users/abetakamitsu/home/vpn-connection


