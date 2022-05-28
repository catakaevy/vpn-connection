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
build: start
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa init-pki
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa build-ca nopass
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa build-server-full server nopass
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa build-client-full client1.domain.tld nopass
	cd easy-rsa/easyrsa3 && pwd && aws acm import-certificate --certificate fileb://pki/issued/server.crt --private-key fileb://pki/private/server.key --certificate-chain fileb://pki/ca.crt > arnmemo.json
	cat easy-rsa/easyrsa3/arnmemo.json | jq -r '.CertificateArn' > arn.txt

#Cleaning directory after generating key
.PHONY: clean
clean: 
	cd easy-rsa/easyrsa3 && pwd && rm -rf pki

#Deleting server-side certificate that you created here in aws with this key
.PHONY: delete_acm
delete_acm:
	aws acm delete-certificate --certificate-arn $(shell cat arn.txt)

#Building Clinent-VPN Endpoint and set up with subnet and internet connection in aws | last part is still required to fix
.PHONY: endpoint
endpoint:
	aws ec2 create-client-vpn-endpoint \
		--client-cidr-block $(CIDR_BLK) \
		--server-certificate-arn $(shell cat arn.txt) \
		--authentication-options Type=certificate-authentication,MutualAuthentication={ClientRootCertificateChainArn=$(shell cat arn.txt)} \
		--connection-log-options Enabled=false > endpointId.txt
		cat endpointId.txt | jq -r '.ClientVpnEndpointId' > endpoint.txt
	aws ec2 associate-client-vpn-target-network \
    --subnet-id $(SUBNET_ID) \
    --client-vpn-endpoint-id $(shell cat endpoint.txt)
	aws ec2 authorize-client-vpn-ingress \
	--client-vpn-endpoint-id $(shell cat endpoint.txt) \
	--target-network-cidr 10.0.0.0/16 \
	--authorize-all-groups
#Moving downloaded-client-config.ovpn to the right directory
.PHONY: mv_set
mv_set:
	mv $(DOWNLOAD_PATH)/downloaded-client-config.ovpn .

#Cleaning up
.PHONY: cleanup
cleanup: delete_acm
	rm arn.txt downloaded-client-config.ovpn
	rm -rf easy-rsa

#cert $(VPN_CONNETION_PATH)/easy-rsa/easyrsa3/pki/issued/client1.domain.tld.crt
#key $(VPN_CONNETION_PATH)/easy-rsa/easyrsa3/pki/private/client1.domain.tld.key




