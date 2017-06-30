#!/bin/bash

jq --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "Please Install 'jq' https://stedolan.github.io/jq/ to execute this script"
	echo
	exit 1
fi
starttime=$(date +%s)
TOTAL_CHANNELS=$1
: ${TOTAL_CHANNELS:=2}
TOTAL_CCS=$2
: ${TOTAL_CCS:=2}
printf "\nTotal Channels : $TOTAL_CHANNELS\n"
printf "Total Chaincodes : $TOTAL_CCS\n"

printf "\nPOST request Enroll user 'Jim' on Org1  ...\n"
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

echo
for (( i=1;i<=$TOTAL_CHANNELS;i=$i+1 )) 
do
printf "\nCreating channel mychannel$i ...\n"
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

printf "\nPOST request Join channel on Org1\n"
curl -s -X POST \
  http://localhost:4000/channels/mychannel$i/peers \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d "{
	\"peers\": [\"localhost:7051\",\"localhost:8051\"]
}"

echo "\n\nPOST request Join channel on Org2\n"
curl -s -X POST \
  http://localhost:4000/channels/mychannel$i/peers \
  -H "authorization: Bearer $ORG2_TOKEN" \
  -H "content-type: application/json" \
  -d "{
	\"peers\": [\"localhost:9051\",\"localhost:10051\"]
}"
echo
done
sleep 5
for (( i=1;i<=$TOTAL_CHANNELS;i=$i+1 ))
do
printf "\nPOST request Update channel with AnchorPeer of Org1\n"
echo
curl -s -X POST \
  http://localhost:4000/channels \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d "{
	\"channelName\":\"mychannel$i\",
	\"channelConfigPath\":\"../artifacts/channel/Org1MSPanchors$i.tx\",
 \"configUpdate\":true
}"
echo
printf "\nPOST request Update channel with AnchorPeer of Org2\n"
echo
curl -s -X POST \
  http://localhost:4000/channels \
  -H "authorization: Bearer $ORG1_TOKEN" \
  -H "content-type: application/json" \
  -d "{
	\"channelName\":\"mychannel$i\",
	\"channelConfigPath\":\"../artifacts/channel/Org2MSPanchors$i.tx\",
 \"configUpdate\":true
}"
done
sleep 5
for (( i=1;i<=$TOTAL_CCS;i=$i+1 ))
do

printf "\n\nPOST Install chaincode mycc$i on Org1\n"
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

printf "\n\nPOST Install chaincode mycc$i on Org2\n"
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
done


sleep 3
for (( ch=1;ch<=$TOTAL_CHANNELS;ch=$ch+1 )) 
do

	for (( cc=1;cc<=$TOTAL_CCS;cc=$cc+1 )) 
	do

		printf "\nPOST instantiate chaincode mycc$cc on Org1 on mychannel$ch\n"
		curl -s -X POST \
		  http://localhost:4000/channels/mychannel$ch/chaincodes \
		  -H "authorization: Bearer $ORG1_TOKEN" \
		  -H "content-type: application/json" \
		  -d "{
			\"peer\":\"peer1\",
			\"chaincodeName\":\"mycc$cc\",
			\"chaincodeVersion\":\"v0\",
			\"functionName\":\"init\",
			\"args\":[\"\"]
		}"
		echo
		sleep 2
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
printf "\nPOST invoke chaincode on peers of Org1/Org2\n"
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
			\"peers\": [\"localhost:7051\"],
			\"fcn\":\"put\",
			\"args\":[\"$ORG1_KEY\",\"$ORG1_VAL\"]
		      }")
	  printf "Transaction on ORG1/PEER1/mycc$cc, TRX_ID $TRX\n"
		sleep 2
		ORG1_Q_RES=$(curl -s -X GET \
		  "http://localhost:4000/channels/mychannel$ch/chaincodes/mycc$cc?peer=peer1&fcn=get&args=%5B%22$ORG1_KEY%22%5D" \
		  -H "authorization: Bearer $ORG1_TOKEN" \
		  -H "content-type: application/json")

		#printf "\nORG1  Key  - $ORG1_KEY\n"
		#printf "\nORG1  Val  - $ORG1_VAL\n"
		#printf "\nQUERY RES1 - $ORG1_Q_RES1\n"
		#printf "\nQUERY RES2 - $ORG1_Q_RES2\n"

		validateResults $ORG1_Q_RES $ORG1_VAL "Query on mychannel$ch on chaincode mycc$cc on PEER1/ORG1 failed"

		ORG2_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )
		ORG2_VAL=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )
		TRX=$(curl -s -X POST http://localhost:4000/channels/mychannel$ch/chaincodes/mycc$cc \
		  -H "authorization: Bearer $ORG2_TOKEN" \
		  -H "content-type: application/json" \
		  -d "{
			\"peers\": [\"localhost:9051\"],
			\"fcn\":\"put\",
			\"args\":[\"$ORG2_KEY\",\"$ORG2_VAL\"]
		}")
		printf "Transaction on ORG2/PEER1/mycc$cc, TRX_ID $TRX\n"
		sleep 2
		ORG2_Q_RES=$(curl -s -X GET \
		  "http://localhost:4000/channels/mychannel$ch/chaincodes/mycc$cc?peer=peer1&fcn=get&args=%5B%22$ORG2_KEY%22%5D" \
		  -H "authorization: Bearer $ORG2_TOKEN" \
		  -H "content-type: application/json")

		#printf "\nORG2  Key  - $ORG2_KEY\n"
		#printf "\nORG2  Val  - $ORG2_VAL\n"
		#printf "\nQUERY RES1 - $ORG2_Q_RES1\n"
		#printf "\nQUERY RES2 - $ORG2_Q_RES2\n"
		validateResults $ORG2_Q_RES $ORG2_VAL "Query on mychannel$ch on chaincode mycc$cc on PEER1/ORG1 failed"


		ORG1_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )
		ORG1_VAL=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )

		TRX=$(curl -s -X POST http://localhost:4000/channels/mychannel$ch/chaincodes/mycc$cc \
		  -H "authorization: Bearer $ORG1_TOKEN" \
		  -H "content-type: application/json" \
		  -d "{
			\"peers\": [\"localhost:8051\"],
			\"fcn\":\"put\",
			\"args\":[\"$ORG1_KEY\",\"$ORG1_VAL\"]
		      }")
		printf "Transaction on ORG1/PEER2/mycc$cc, TRX_ID $TRX\n"
		sleep 2
		ORG1_Q_RES=$(curl -s -X GET \
		  "http://localhost:4000/channels/mychannel$ch/chaincodes/mycc$cc?peer=peer2&fcn=get&args=%5B%22$ORG1_KEY%22%5D" \
		  -H "authorization: Bearer $ORG1_TOKEN" \
		  -H "content-type: application/json")

		#printf "\nORG1  Key  - $ORG1_KEY\n"
		#printf "\nORG1  Val  - $ORG1_VAL\n"
		#printf "\nQUERY RES1 - $ORG1_Q_RES1\n"
		#printf "\nQUERY RES2 - $ORG1_Q_RES2\n"

		validateResults $ORG1_Q_RES $ORG1_VAL "Query on mychannel$ch on chaincode mycc$cc on PEER2/ORG1 failed"

		ORG2_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )
		ORG2_VAL=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1 )
		TRX=$(curl -s -X POST http://localhost:4000/channels/mychannel$ch/chaincodes/mycc$cc \
		  -H "authorization: Bearer $ORG2_TOKEN" \
		  -H "content-type: application/json" \
		  -d "{
			\"peers\": [\"localhost:10051\"],
			\"fcn\":\"put\",
			\"args\":[\"$ORG2_KEY\",\"$ORG2_VAL\"]
		}")
		printf "Transaction on ORG2/PEER2/mycc$cc, TRX_ID $TRX\n"
		sleep 2
		ORG2_Q_RES=$(curl -s -X GET \
		  "http://localhost:4000/channels/mychannel$ch/chaincodes/mycc$cc?peer=peer2&fcn=get&args=%5B%22$ORG2_KEY%22%5D" \
		  -H "authorization: Bearer $ORG2_TOKEN" \
		  -H "content-type: application/json")

		#printf "\nORG2  Key  - $ORG2_KEY\n"
		#printf "\nORG2  Val  - $ORG2_VAL\n"
		#printf "\nQUERY RES1 - $ORG2_Q_RES1\n"
		#printf "\nQUERY RES2 - $ORG2_Q_RES2\n"
		validateResults $ORG2_Q_RES $ORG2_VAL "Query on mychannel$ch on chaincode mycc$cc on PEER2/ORG1 failed"

		COUNTER=` expr $COUNTER + 4 `
	done
	printf "\n########### Transactions completed so far $COUNTER ##############\n"
done

echo
printf "\n\nTotal execution time : $(($(date +%s)-starttime)) secs ...\n"
