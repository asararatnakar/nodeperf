#!/bin/bash

jq --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Please Install 'jq' https://stedolan.github.io/jq/ to execute this script"
	echo
	exit 1
fi
starttime=$(date +%s)
TOTAL_CHANNELS=$1
: ${TOTAL_CHANNELS:=50}
TOTAL_CCS=$2
: ${TOTAL_CCS:=10}

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

echo "POST request Enroll user 'Ratz' on Org1  ..."
echo
TEMP_TOKEN=$(curl -s -X POST \
  http://localhost:4000/users \
  -H "content-type: application/x-www-form-urlencoded" \
  -d 'username=Ratz&orgName=org1')
TEMP_TOKEN=$(echo $TEMP_TOKEN | jq ".token" | sed "s/\"//g")
echo
echo "GET request to revoke user 'Ratz' on Org1  ..."
echo
curl -s -X GET \
  "http://localhost:4000/revoke" \
  -H "authorization: Bearer $TEMP_TOKEN" \
  -H "content-type: application/json"
echo
echo

echo
for (( i=1;i<=$TOTAL_CHANNELS;i=$i+1 )) 
do
echo "Creating channel mychannel$i ..."
curl -s -X POST \
  http://localhost:4000/channels \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d "{
	\"channelName\":\"mychannel$i\",
	\"channelConfigPath\":\"../artifacts/channel/mychannel$i.tx\",
	\"configUpdate\":false
}"
done
echo
sleep 10

for (( i=1;i<=$TOTAL_CHANNELS;i=$i+1 )) 
do

echo "POST request Join channel on Org1"
echo
curl -s -X POST \
  http://localhost:4000/channels/mychannel$i/peers \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d "{
	\"peers\": [\"localhost:7051\",\"localhost:8051\"]
}"
echo
echo

echo "POST request Join channel on Org2"
echo
curl -s -X POST \
  http://localhost:4000/channels/mychannel$i/peers \
  -H "authorization: Bearer $ORG2_TOKEN" \
  -H "content-type: application/json" \
  -d "{
	\"peers\": [\"localhost:9051\",\"localhost:10051\"]
}"
echo
echo
done
sleep 5

for (( i=1;i<=$TOTAL_CCS;i=$i+1 )) 
do

echo "POST Install chaincode on Org1"
echo
curl -s -X POST \
  http://localhost:4000/chaincodes \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d "{
	\"peers\": [\"localhost:7051\",\"localhost:8051\"],
	\"chaincodeName\":\"mycc$i\",
	\"chaincodePath\":\"github.com/uniqueKeyValue\",
	\"chaincodeVersion\":\"v0\"
}"

echo
echo

echo "POST Install chaincode on Org2"
echo
curl -s -X POST \
  http://localhost:4000/chaincodes \
  -H "authorization: Bearer $ORG2_TOKEN" \
  -H "content-type: application/json" \
  -d "{
	\"peers\": [\"localhost:9051\",\"localhost:10051\"],
	\"chaincodeName\":\"mycc$i\",
	\"chaincodePath\":\"github.com/uniqueKeyValue\",
	\"chaincodeVersion\":\"v0\"
}"
echo
echo
done


sleep 3
for (( ch=1;ch<=$TOTAL_CHANNELS;ch=$ch+1 )) 
do

	for (( cc=1;cc<=$TOTAL_CCS;cc=$cc+1 )) 
	do

		echo "POST instantiate chaincode mycc$cc on Org1 on mychannel$ch"
		echo
		curl -s -X POST \
		  http://localhost:4000/channels/mychannel$ch/chaincodes \
		  -H "authorization: Bearer $ORG1_TOKEN" \
		  -H "content-type: application/json" \
		  -d "{
			\"chaincodeName\":\"mycc$cc\",
			\"chaincodeVersion\":\"v0\",
			\"functionName\":\"init\",
			\"args\":[\"\"]
		}"
		echo
	done
done

sleep 10
function validateResults () {
	if [ "$1" != "$2" ]; then
		printf "\n$3\n"
		printf "\n!!!!!!!!!!!  RESULTS MISMATCH   !!!!!!!!!!!!!!!\n"
		printf "\n\nTotal execution time : $(($(date +%s)-starttime)) secs ...\n"
		exit
	fi
}
echo "POST invoke chaincode on peers of Org1/Org2"
COUNTER=0
for (( ch=1;ch<=$TOTAL_CHANNELS;ch=$ch+1 )) 
do
  printf "\n################## CHANNEL$ch ####################\n"
	for (( cc=1;cc<=$TOTAL_CCS;cc=$cc+1 )) 
	do
		ORG1_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )
		ORG1_VAL=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )

		TRX=$(curl -s -X POST http://localhost:4000/channels/mychannel$ch/chaincodes/mycc$cc \
		  -H "authorization: Bearer $ORG1_TOKEN" \
		  -H "content-type: application/json" \
		  -d "{
			\"peers\": [\"localhost:7051\", \"localhost:8051\"],
			\"fcn\":\"put\",
			\"args\":[\"$ORG1_KEY\",\"$ORG1_VAL\"]
		      }")
	        printf "Transaction on ORG1 on mycc$cc, TRX_ID $TRX\n"
		ORG1_Q_RES1=$(curl -s -X GET \
		  "http://localhost:4000/channels/mychannel$ch/chaincodes/mycc$cc?peer=peer1&fcn=get&args=%5B%22$ORG1_KEY%22%5D" \
		  -H "authorization: Bearer $ORG1_TOKEN" \
		  -H "content-type: application/json")
		ORG1_Q_RES2=$(curl -s -X GET \
		  "http://localhost:4000/channels/mychannel$ch/chaincodes/mycc$cc?peer=peer2&fcn=get&args=%5B%22$ORG1_KEY%22%5D" \
		  -H "authorization: Bearer $ORG1_TOKEN" \
		  -H "content-type: application/json")

		#printf "\nORG1  Key  - $ORG1_KEY\n"
		#printf "\nORG1  Val  - $ORG1_VAL\n"
		#printf "\nQUERY RES1 - $ORG1_Q_RES1\n"
		#printf "\nQUERY RES2 - $ORG1_Q_RES2\n"

		validateResults $ORG1_Q_RES1 $ORG1_VAL "Query on mychannel$ch on chaincode mycc$cc on PEER0/ORG1 failed"
		validateResults $ORG1_Q_RES2 $ORG1_VAL "Query on mychannel$ch on chaincode mycc$cc on PEER1/ORG1 failed"

		ORG2_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )
		ORG2_VAL=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )
		TRX=$(curl -s -X POST http://localhost:4000/channels/mychannel$ch/chaincodes/mycc$cc \
		  -H "authorization: Bearer $ORG2_TOKEN" \
		  -H "content-type: application/json" \
		  -d "{
			\"peers\": [\"localhost:9051\", \"localhost:10051\"],
			\"fcn\":\"put\",
			\"args\":[\"$ORG2_KEY\",\"$ORG2_VAL\"]
		}")
		printf "Transaction on ORG2 on mycc$cc, TRX_ID $TRX\n"
		ORG2_Q_RES1=$(curl -s -X GET \
		  "http://localhost:4000/channels/mychannel$ch/chaincodes/mycc$cc?peer=peer1&fcn=get&args=%5B%22$ORG2_KEY%22%5D" \
		  -H "authorization: Bearer $ORG2_TOKEN" \
		  -H "content-type: application/json")
		ORG2_Q_RES2=$(curl -s -X GET \
		  "http://localhost:4000/channels/mychannel$ch/chaincodes/mycc$cc?peer=peer2&fcn=get&args=%5B%22$ORG2_KEY%22%5D" \
		  -H "authorization: Bearer $ORG2_TOKEN" \
		  -H "content-type: application/json")

		#printf "\nORG2  Key  - $ORG2_KEY\n"
		#printf "\nORG2  Val  - $ORG2_VAL\n"
		#printf "\nQUERY RES1 - $ORG2_Q_RES1\n"
		#printf "\nQUERY RES2 - $ORG2_Q_RES2\n"
		validateResults $ORG2_Q_RES1 $ORG2_VAL "Query on mychannel$ch on chaincode mycc$cc on PEER0/ORG1 failed"
		validateResults $ORG2_Q_RES2 $ORG2_VAL "Query on mychannel$ch on chaincode mycc$cc on PEER1/ORG1 failed"
		COUNTER=` expr $COUNTER + 2 `
	done
	printf "\n########### Transactions completed so far $COUNTER ##############\n"
done


echo
printf "\n\nTotal execution time : $(($(date +%s)-starttime)) secs ...\n"
