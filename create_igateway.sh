#!/bin/bash
# Author Brokedba https://twitter.com/BrokeDba
RED=$'\e\033[0;31m'
GREEN=$'\e\033[0;32m'
BLUE=$'\e\033[1;34m'
NC=$'\e\033[0m' # No Color
echo
while true; do
 aws ec2 describe-vpcs --vpc-ids $vpc_id --query   'Vpcs[].{VPCID:VpcId,association:CidrBlockAssociationSet[].CidrBlockState.State| [0],CIDR:CidrBlock,Name:Tags[?Key==`Name`].Value| [0]}'
 read -p "select the vpc you wish to add the I-Gateway to [$vpc_name]: " vpc_name
 vpc_name=${vpc_name:-$vpc_name}
 vpc_id=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=$vpc_name  --query   'Vpcs[].VpcId' --output text)
if [ -n "$vpc_id" ];
    then  
     echo -e selected vpc name :${GREEN} $vpc_name${NC}
     igw_id=$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$vpc_id --query InternetGateways[].InternetGatewayId --output text) 
     if ! [ -n "$igw_id" ];
     then echo -e " ${GREEN} Creating a New Internet gateway:${NC}"
     echo ...
     break
     else echo "An Internet Gateway exists already for ${GREEN}$vpc_name:${NC}. No Action needed.";
     exit 1
     fi 
else echo "The entered vpc name is not valid. Please retry"; 
 fi
done        
 read -p "Enter the Internet gateway name you wish to create [${GREEN} CLI-IGW ${NC}]: " igw_name
igw_name=${igw_name:-CLI-IGW}
igw_id=$(aws ec2 create-internet-gateway  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$igw_name}]" --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' --output text  ) #--region $AWS_REGION
aws ec2 attach-internet-gateway   --vpc-id $vpc_id  --internet-gateway-id $igw_id # --region $AWS_REGION
echo "==== Created Internet gateway Details ===="
aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$vpc_id --query 'InternetGateways[].{Igw_id:InternetGatewayId, Vpc_id:Attachments[].VpcId|[0],State:Attachments[].State|[0],Name:Tags[?Key==`Name`].Value| [0]}' 
echo
echo -e "detach command ==> ${RED} aws ec2 detach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id${NC}"  
echo -e "delete command ==> ${RED} aws ec2 delete-internet-gateway --internet-gateway-id $igw_id"  