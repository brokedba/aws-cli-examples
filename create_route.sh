#!/bin/bash
# Author Brokedba https://twitter.com/BrokeDba
RED=$'\e\033[0;31m'
GREEN=$'\e\033[0;32m'
BLUE=$'\e\033[1;34m'
NC=$'\e\033[0m' # No Color
echo
while true; do
 aws ec2 describe-vpcs  --query   'Vpcs[].{VPCID:VpcId,association:CidrBlockAssociationSet[].CidrBlockState.State| [0],CIDR:CidrBlock,Name:Tags[?Key==`Name`].Value| [0]}'
 read -p "select the VPC Name you wish to set the route table for [$vpc_name]: " vpc_name
 vpc_name=${vpc_name:-$vpc_name}
 vpc_id=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=$vpc_name  --query   'Vpcs[].VpcId' --output text)
if [ -n "$vpc_id" ];
    then  
     echo selected VPC name :${GREEN} $vpc_name${NC}
     igw_id=$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$vpc_id --query 'InternetGateways[].InternetGatewayId' --output text) 
     if  [ -n "$igw_id" ];
     then echo 
     echo "${GREEN} Internet gateway exists => checking the subnet availability${NC}"
     echo ...
     break
     else echo " ${RED}Internet Gateway doesn't exist for $vpc_name. Please run create_igateway.sh script first. ${NC}";
     exit 1
     fi 
else echo "${RED}The entered VPC name is not valid. Please retry${NC}"; 
 fi
 done
while true; do
sub_id=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text)
if [ -n "$sub_id" ];
    then  
     aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].{VPC_id:VpcId,SUB_id:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock,AutoIP:MapPublicIpOnLaunch,IP_COUNT:AvailableIpAddressCount,Name:Tags[?Key==`Name`].Value| [0]}' 
     read -p "select the subnet Name you wish to set the route table for [$sub_name]: " sub_name
     sub_name=${sub_name:-$sub_name}
     sub_id=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=$sub_name"  --query   'Subnets[].SubnetId' --output text)
     echo selected subnet name : ${GREEN}$sub_name${NC} 
     if  [ -n "$sub_id" ];
     then echo
     echo " ${GREEN}Internet gateway and subnet exist => Seting up the default Route table${NC}"
     echo ...
     break
     else echo " ${RED}The entered Subnet name doesn't exist for $vpc_name. Please retry!${NC}";
     fi 
else echo "${RED}The entered VPC name has no subnet. Please choose another vpc or create a new subnet using create_subnet.sh first.${NC}"; 
exit 1
 fi 
done 
echo "${GREEN} Create Route Table ${NC}"
rt_id=$(aws ec2 create-route-table   --vpc-id $vpc_id --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=rt_$sub_name}]" --query 'RouteTable.{RouteTableId:RouteTableId}' --output text ) #--region $AWS_REGION       
echo "${GREEN} Create route to Internet Gateway for Route Table ID '$rt_id'.${NC}" 
aws ec2 create-route --route-table-id $rt_id --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id  #--region $AWS_REGION
echo ...
echo  " ${GREEN} Associate '$sub_name' Subnet with the Route Table.${NC}"
aws ec2 associate-route-table --subnet-id $sub_id --route-table-id $rt_id  #--region $AWS_REGION
 echo
echo "====${GREEN} Default Route table entries for $sub_name ${NC}===="
echo
 aws ec2 describe-route-tables  --route-table-id $rt_id --query 'RouteTables[*].{rt_id:RouteTableId,Vpc_id:VpcId, Main:Associations[].Main| [0],Routes:Routes,Name:Tags[?Key==`Name`].Value| [0]}'
asos_id=$(aws ec2 describe-route-tables --query "RouteTables[].Associations[?SubnetId =='$sub_id'].RouteTableAssociationId[]" --output text)
echo
echo -e "detach route command       ==> ${RED} aws ec2 disassociate-route-table --association-id $asos_id ${NC}"  
echo -e "delete route command       ==> ${RED} aws ec2 delete-route --route-table-id $rt_id --destination-cidr-block 0.0.0.0/0${NC}"  
echo -e "delete route-table command ==> ${RED} aws ec2 delete-route-table --route-table-id $rt_id${NC}"