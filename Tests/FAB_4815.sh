#!/bin/bash

jq --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Please Install 'jq' https://stedolan.github.io/jq/ to execute this script"
	echo
	exit 1
fi
starttime=$(date +%s)

echo "POST request Enroll user 'Jim' on Org1  ..."
echo
ORG1_TOKEN=$(curl -s -X POST \
  http://localhost:4000/users \
  -H "content-type: application/x-www-form-urlencoded" \
  -d 'username=Jim&orgName=org1')
echo $ORG1_TOKEN
ORG1_TOKEN=$(echo $ORG1_TOKEN | jq ".token" | sed "s/\"//g")
echo
echo "ORG1 token is $ORG1_TOKEN"
echo

echo "POST request Enroll user 'Barry' on Org2 ..."
echo
ORG2_TOKEN=$(curl -s -X POST \
  http://localhost:4000/users \
  -H "content-type: application/x-www-form-urlencoded" \
  -d 'username=Barry&orgName=org2')
echo $ORG2_TOKEN
ORG2_TOKEN=$(echo $ORG2_TOKEN | jq ".token" | sed "s/\"//g")
echo
echo "ORG2 token is $ORG2_TOKEN"

echo
echo "POST request Create channel  ..."
echo
curl -s -X POST \
  http://localhost:4000/channels \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"channelName":"mychannel1",
	"channelConfigPath":"../artifacts/channel/mychannel1.tx",
	"configUpdate":false
}'
echo
echo
sleep 10
echo "POST request Join channel on Org1"
echo
curl -s -X POST \
  http://localhost:4000/channels/mychannel1/peers \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"peers": ["localhost:7051","localhost:8051"]
}'
echo
echo

echo "POST Install chaincode on Org1"
echo
curl -s -X POST \
  http://localhost:4000/chaincodes \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"peers": ["localhost:7051","localhost:8051"],
	"chaincodeName":"mycc",
	"chaincodePath":"github.com/uniqueKeyValue",
	"chaincodeVersion":"v0"
}'
echo
echo

echo "POST Install chaincode on Org2"
echo
curl -s -X POST \
  http://localhost:4000/chaincodes \
  -H "authorization: Bearer $ORG2_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"peers": ["localhost:9051","localhost:10051"],
	"chaincodeName":"mycc",
	"chaincodePath":"github.com/uniqueKeyValue",
	"chaincodeVersion":"v0"
}'
echo
echo


echo "POST instantiate chaincode on peer1 of Org1 on mychannel1"
echo
curl -s -X POST \
  http://localhost:4000/channels/mychannel1/chaincodes \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"chaincodeName":"mycc",
	"chaincodeVersion":"v0",
	"functionName":"init",
	"args":[""]
}'
echo

# TODO: Should try to use random payload
#RANDOM_STR=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 1024 | head -n 1)
echo "POST invoke chaincode on peers of Org1"
echo
TRX_ID=$(curl -s -X POST \
  http://localhost:4000/channels/mychannel1/chaincodes/mycc \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"peers": ["localhost:7051", "localhost:8051"],
	"fcn":"put",
	"args":["org1","putsomerandomvalue-org1"]
}')
echo "Transacton ID is $TRX_ID"
echo
echo

echo "GET query chaincode on peer1 of Org1"
echo
curl -s -X GET \
  "http://localhost:4000/channels/mychannel1/chaincodes/mycc?peer=peer1&fcn=get&args=%5B%22org1%22%5D" \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json"
echo
echo


echo "POST request Create channel  ..."
echo
curl -s -X POST \
  http://localhost:4000/channels \
  -H "authorization: Bearer $ORG2_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"channelName":"mychannel2",
	"channelConfigPath":"../artifacts/channel/mychannel2.tx"
}'
echo
echo
sleep 10


echo "POST request Join channel on Org2"
echo
curl -s -X POST \
  http://localhost:4000/channels/mychannel2/peers \
  -H "authorization: Bearer $ORG2_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"peers": ["localhost:9051","localhost:10051"]
}'
echo
echo


echo
echo "POST instantiate chaincode on peer1 of Org2 on mychannel2"
echo
curl -s -X POST \
  http://localhost:4000/channels/mychannel2/chaincodes \
  -H "authorization: Bearer $ORG2_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"chaincodeName":"mycc",
	"chaincodeVersion":"v0",
	"functionName":"init",
	"args":[""]
}'
echo
echo
echo "POST invoke chaincode on peers of Org1 on mychannel1"
echo
TRX_ID2=$(curl -s -X POST \
  http://localhost:4000/channels/mychannel2/chaincodes/mycc \
  -H "authorization: Bearer $ORG2_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"peers": ["localhost:9051", "localhost:10051"],
	"fcn":"put",
	"args":["ORG2","putsomerandomvalue-ORG2"]
}')
echo "Transacton ID is $TRX_ID2"
echo
echo

curl -s -X GET \
  "http://localhost:4000/channels/mychannel2/chaincodes/mycc?peer=peer1&fcn=get&args=%5B%22ORG2%22%5D" \
  -H "authorization: Bearer $ORG2_TOKEN" \
  -H "content-type: application/json"
echo
echo

echo "POST invoke chaincode on peers of Org1 on mychannel1"
echo
TRX_ID2=$(curl -s -X POST \
  http://localhost:4000/channels/mychannel1/chaincodes/mycc \
  -H "authorization: Bearer $ORG2_TOKEN" \
  -H "content-type: application/json" \
  -d '{
	"peers": ["localhost:9051", "localhost:10051"],
	"fcn":"put",
	"args":["ORG1","putsomerandomvalue-ORG1"]
}')
echo "Transacton ID is $TRX_ID2"
echo
echo

curl -s -X GET \
  "http://localhost:4000/channels/mychannel1/chaincodes/mycc?peer=peer1&fcn=get&args=%5B%22ORG1%22%5D" \
  -H "authorization: Bearer $ORG2_TOKEN" \
  -H "content-type: application/json"
echo
echo

echo
printf "\nTotal execution time : $(($(date +%s)-starttime)) secs ...\n\n"
