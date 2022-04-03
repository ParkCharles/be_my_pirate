#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#
# Exit on first error, print all commands.
set -ev

# don't rewrite paths for Windows Git Bash users
export MSYS_NO_PATHCONV=1

# generate.sh 가 수행된 다음 # 발행된 CA_PRIVATE_KEY를 가져와서 # docker-compose 파일에 저장
export CA_PRIVATE_KEY=$(cd crypto-config/peerOrganizations/org1.example.com/ca && ls *_sk)
sed -i "s/CA_PRIVATE_KEY/${CA_PRIVATE_KEY}/g" docker-compose.yml

function checkPrereqs() {
    # check config dir
    if [ ! -d "crypto-config" ]; then
        echo "crypto-config dir missing"
        exit 1
    fi
    # check crypto-config dir
     if [ ! -d "config" ]; then
        echo "config dir missing"
        exit 1
    fi
}

checkPrereqs

docker-compose -f docker-compose.yml down

docker-compose -f docker-compose.yml up -d ca.example.com orderer.example.com couchdb1 couchdb2 couchdb3 peer0.org1.example.com  peer0.org2.example.com peer0.org3.example.com cli
docker ps -a

# wait for Hyperledger Fabric to start
# incase of errors when running later commands, issue export FABRIC_START_TIMEOUT=<larger number>
export FABRIC_START_TIMEOUT=10
#echo ${FABRIC_START_TIMEOUT}
sleep ${FABRIC_START_TIMEOUT}

# Create the channel
docker exec cli peer channel create -o orderer.example.com:7050 -c mychannel -f /etc/hyperledger/configtx/channel.tx
# Join peer0.org1.example.com to the channel.
docker exec -e "CORE_PEER_LOCALMSPID=Org1MSP" -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@org1.example.com/msp" peer0.org1.example.com peer channel join -b /etc/hyperledger/configtx/mychannel.block
sleep 3
# Join peer0.org2.example.com to the channel.
docker exec -e "CORE_PEER_LOCALMSPID=Org2MSP" -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@org2.example.com/msp" peer0.org2.example.com peer channel join -b /etc/hyperledger/configtx/mychannel.block
sleep 3
# Join peer0.org2.example.com to the channel.
docker exec -e "CORE_PEER_LOCALMSPID=Org3MSP" -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@org3.example.com/msp" peer0.org3.example.com peer channel join -b /etc/hyperledger/configtx/mychannel.block
sleep 3

# 채널 조인 확인
docker exec -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@org1.example.com/msp" peer0.org1.example.com peer channel list
docker exec -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@org2.example.com/msp" peer0.org2.example.com peer channel list
docker exec -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@org3.example.com/msp" peer0.org3.example.com peer channel list

# 앵커 피어 업데이트
docker exec -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@org1.example.com/msp" peer0.org1.example.com peer channel update -f /etc/hyperledger/configtx/Org1MSPanchors.tx -o orderer.example.com:7050 -c mychannel
docker exec -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@org2.example.com/msp" peer0.org2.example.com peer channel update -f /etc/hyperledger/configtx/Org2MSPanchors.tx -o orderer.example.com:7050 -c mychannel
docker exec -e "CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/users/Admin@org3.example.com/msp" peer0.org3.example.com peer channel update -f /etc/hyperledger/configtx/Org3MSPanchors.tx -o orderer.example.com:7050 -c mychannel

