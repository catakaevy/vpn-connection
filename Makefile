#Variables Setup
BucketName:=
StackName:=
VPCSetup:=
KeyPair:=
ProjectName:=
VPCCidr:=
#Subnet CIDR must be more than /27
PublicSubnetCidr:=
Region:=

#Cloning & Change Dir to clone_dir
.PHONY: start
start:
	git clone git@github.com:OpenVPN/easy-rsa.git

#Region Check
.PHONY: region
region: 
	aws ec2 describe-regions

#Generating init-pki and Building CA and Sv&Cl key-pairs | if you want to change the region, use this "export AWS_DEFAULT_REGION=us-west-2"
.PHONY: cert-build
cert-build: start
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa init-pki
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa build-ca nopass
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa build-server-full server nopass
	cd easy-rsa/easyrsa3 && pwd && ./easyrsa build-client-full client1.domain.tld nopass
	cd easy-rsa/easyrsa3 && pwd && aws acm import-certificate --certificate fileb://pki/issued/server.crt --private-key fileb://pki/private/server.key --certificate-chain fileb://pki/ca.crt --region $(Region) > arnmemoserver.json
	cd easy-rsa/easyrsa3 && pwd && aws acm import-certificate --certificate fileb://pki/issued/client1.domain.tld.crt --private-key fileb://pki/private/client1.domain.tld.key --certificate-chain fileb://pki/ca.crt --region $(Region) > arnmemoclient.json
	cat easy-rsa/easyrsa3/arnmemoserver.json | jq -r '.CertificateArn' > servercertarn.txt
	cat easy-rsa/easyrsa3/arnmemoclient.json | jq -r '.CertificateArn' > clientcertarn.txt

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

#Root Stack preps
.PHONY: preps
 preps:
	aws s3 sync ./rsc/child-stack/ s3://$(BucketName) 

#Root Stack Deployment
.PHONY: deploy
 deploy: preps
	aws cloudformation deploy --stack-name $(StackName) --template-file ./rsc/root-stack.yml --parameter-overrides ProjectName=$(ProjectName) ServerCertificateArn=$(shell cat servercertarn.txt) ClientCertificateArn=$(shell cat clientcertarn.txt) TemplateS3BucketName=$(BucketName) --region $(Region) --capabilities CAPABILITY_NAMED_IAM

#Root Stack Deletion
.PHONY: delete
 delete: 
	aws cloudformation delete-stack --stack-name $(StackName) --region $(Region)

#Everything Deletion
.PHONY: clean
 clean: delete 
	rm clientcertarn.txt && rm servercertarn.txt
	rm -rf easy-rsa

#CloudFormation Main Deployment
.PHONY: cfn_deploy
 cfn_deploy:
	aws cloudformation deploy --stack-name $(VPCSetup) --template-file ./rsc/child-stack/VPCSetup.yml --parameter-overrides ProjectName=$(ProjectName) VPCCidr=$(VPCCidr) PublicSubnetCidr=$(PublicSubnetCidr) --region $(Region)
	aws cloudformation deploy --stack-name $(KeyPair) --template-file ./rsc/child-stack/KeyPair.yml --parameter-overrides ProjectName=$(ProjectName) --region $(Region)

#CloudFormation Individual Deployment Type
.PHONY: cfn_vpc
 cfn_vpc:
	aws cloudformation deploy --stack-name $(VPCSetup) --template-file ./rsc/child-stack/VPCSetup.yml --parameter-overrides ProjectName=$(ProjectName) VPCCidr=$(VPCCidr) PublicSubnetCidr=$(PublicSubnetCidr) --region $(Region)

.PHONY: cfn_key
 cfn_key:
	aws cloudformation deploy --stack-name $(KeyPair) --template-file ./rsc/child-stack/KeyPair.yml --parameter-overrides ProjectName=$(ProjectName) --region $(Region)

.PHONY: cfn_ec2
 cfn_vpc:
	aws cloudformation deploy --stack-name $(BationEC2) --template-file ./rsc/child-stack/BationEC2.yml --parameter-overrides ProjectName=$(ProjectName) VPCCidr=$(VPCCidr) PublicSubnetCidr=$(PublicSubnetCidr) --region $(Region)

.PHONY: cfn_vpn
 cfn_vpn:
	aws cloudformation deploy --stack-name $(ClientVPNEndpoint) --template-file ./rsc/child-stack/ClientVPNEndpoint.yml --parameter-overrides ProjectName=$(ProjectName) VPCCidr=$(VPCCidr) PublicSubnetCidr=$(PublicSubnetCidr) --region $(Region)

#CloudFormation Deletion
.PHONY: cfn_delete
 cfn_delete:
	aws cloudformation delete-stack --stack-name $(VPCSetup) --region $(Region)
	aws cloudformation delete-stack --stack-name $(KeyPair) --region $(Region)



