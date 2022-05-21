import json
import os

input_path = os.environ['VPN_CONNECTION_PATH']+"/easy-rsa/easyrsa3/arnmemo.json"
json_open = open(input_path, 'r')
json_load = json.load(json_open)
result = (json_load['CertificateArn'])
arn_reference = open("arn.txt", 'w')
arn_reference.write(result)
arn_reference.close()