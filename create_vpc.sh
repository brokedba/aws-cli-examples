#!/bin/bash
# Author Brokedba https://twitter.com/BrokeDba
RED=$'\e\033[0;31m'
GREEN=$'\e\033[0;32m'
BLUE=$'\e\033[1;34m'
NC=$'\e\033[0m' # No Color
# echo -e "Note:  ${RED} VPC CIDR ${GREEN} range is /16 to /18 and last octet is always zeroed even if you specify a non zero value ${NC}"
echo
read -p "Enter the VPC name you wish to create [${BLUE}CLI-VPC${NC}]: " vpc_name
vpc_name=${vpc_name:-CLI-VPC}
echo -e selected VPC name : ${GREEN}$vpc_name${NC}
if [ -z "$vpc_name" ];
    then  echo "The entered name is not valid ";
else
    while true; do
        read -p " Enter the VPC network CIDR to assign '/16-to-/28' [${BLUE}192.168.0.0/16${NC}]: " vpc_cidr
        vpc_cidr=${vpc_cidr:-"192.168.0.0/16"};
        if [ "$vpc_cidr" = "" ] 
            then echo -e "${RED}Entered CIDR is not valid. Please retry${NC}"
            else
             REGEX='^(((25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?))(\/([1][6-9]|[2][0-8]))([^0-9.]|$)'
                 if [[ $vpc_cidr =~ $REGEX ]]
            then
            echo
            echo -e "  === VPC information ===" 
            echo -e "   VPC name = ${GREEN} $vpc_name ${NC}" 
            echo -e "   CIDR = ${GREEN} $vpc_cidr${NC}"
            break
            else
                        echo -e "${RED} Entered CIDR is not valid. Please retry${NC}"
            fi
        fi    
    done                
fi
vpc_id=$(aws ec2 create-vpc --cidr-block $vpc_cidr --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$vpc_name}]"  --query Vpc.VpcId --output text) 
#aws ec2 create-tags --resources $vpc_id  --tags Key=Name,Value=$vpc_name
#aws ec2 create-vpc --cidr-block  $vpc_cidr --output text | awk '{print $NF}' | xargs aws ec2 create-tags --tags Key=Name,Value=$vpc_name --resources
echo
echo -e "${NC} ==== Created VPC details ===="
 #aws ec2 describe-vpcs --vpc-ids $vpc_id
 aws ec2 describe-vpcs --vpc-ids $vpc_id --query   'Vpcs[].{VPCID:VpcId,association:CidrBlockAssociationSet[].CidrBlockState.State| [0],CIDR:CidrBlock,Name:Tags[?Key==`Name`].Value| [0]}'
echo -e Note : ${GREEN}the last octet is always zeroed even if you specify a non zero value${NC}
echo
echo "************ Security Group ! ************"
echo "   Choose The type of security Group you want to create ||{**}||${GREEN}"  
PS3='Select a security group ingress rule and press Enter: ' 
options=("SSH port Only" "SSH, HTTP, and HTTPS" "SSH ,HTTP,RDP, and HTTPS")
select opt in "${options[@]}"
do
  case $opt in
        "SSH port Only")
          sg_id=$(aws ec2 create-security-group --group-name sg_$vpc_name --description "SSH port Only" --vpc-id $vpc_id --query GroupId --output text) 
          aws ec2 authorize-security-group-ingress --group-id $sg_id --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound SSH access"}]'
          break
          ;;
        "SSH, HTTP, and HTTPS")
          sg_id=$(aws ec2 create-security-group --group-name sg_$vpc_name --description "SSH and HTTP" --vpc-id $vpc_id --query GroupId --output text) 
          aws ec2 authorize-security-group-ingress --group-id $sg_id --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound SSH access"}]' IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound HTTP access "}]'
          break
          ;;
          
        "SSH ,HTTP,RDP, and HTTPS")
          sg_id=$(aws ec2 create-security-group --group-name sg_$vpc_name --description "SSH ,HTTP, and HTTPS" --vpc-id $vpc_id --query GroupId --output text) 
          aws ec2 authorize-security-group-ingress --group-id $sg_id --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound SSH access"}]' IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound HTTP access "}]' IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound HTTPS access"}]' IpProtocol=tcp,FromPort=3389,ToPort=3389,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound RDP access"}]'
          break
          ;;               
        *) echo "invalid option";;
  esac
done
echo
echo -e "${NC}*******************${GREEN}  Security Group detail${NC}  ******************"
echo
aws ec2 describe-security-groups --group-id $sg_id  --query  'SecurityGroups[].{SG_id:GroupId,Name:GroupName,Vpc_id:VpcId,"Rules": IpPermissions[].{SourceCIDR:IpRanges[].CidrIp|[0],Description:IpRanges[].Description|[0],fromport:FromPort,ToPort:ToPort,Protocol:IpProtocol}}'
echo
echo -e "${NC} SG delete command  ==>${RED} aws ec2 delete-security-group --group-id $sg_id"
echo -e "${NC} VPC delete command ==>${RED}  aws ec2 delete-vpc --vpc-id $vpc_id" 
