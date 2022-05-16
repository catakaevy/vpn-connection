#Generating init-pki and Building CA and Sv&Cl key-pairs
.PHONY: build
build:
	./easyrsa init-pki
	./easyrsa build-ca nopass
	./easyrsa build-server-full server nopass
	./easyrsa build-client-full client1.domain.tld nopass

#Sending private-key and certificate to aws account manager
.PHONY: send
send:
	make build
	aws acm import-certificate --certificate fileb://pki/issued/server.crt --private-key fileb://pki/private/server.key --certificate-chain fileb://pki/ca.crt --region ap-south-1
	make clean

#Cleaning directory after generating key
.PHONY: clean
clean: rm -rf pki

#Deleting all server-side certificate in aws with this key not yet how to do...
.PHONY: delete_acm
delete1: 
	aws acm list-certificates
#I want to delete all certifictes simultaneously however, I could not even execute delete-certificate command with Error "no resource found..".
#.PHONY: delete2
#delete2:
#	aws acm delete-certificate --certificate-arn $(shell sed -l 84 $(

#Building Clinent-VPN Endpoint in aws


