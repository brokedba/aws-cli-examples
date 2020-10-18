#!/bin/bash
# Author Brokedba https://twitter.com/BrokeDba
echo "******* AWS instance launch ! ************"
echo
RED=$'\e\033[0;31m'
GREEN=$'\e\033[0;32m'
BLUE=$'\e\033[1;34m'
NC=$'\e\033[0m' # No Color
echo -e "Note: ${RED} t2.Micro${GREEN} is the default FreeTier elligible instance type used here ${BLUE}[Default option =Micro compute]${NC}"
#read -p "Enter the Shape name you wish to create [VM.Standard.E2.1.Micro]: " shape
inst_type=$(aws ec2 describe-instance-types --filters "Name=free-tier-eligible,Values=true" "Name=current-generation,Values=true" --query 'InstanceTypes[].InstanceType' --output text)

read -p "Enter the Path of your ssh key [~/id_rsa_aws.pub]: " public_key
public_key=${public_key:-~/id_rsa_aws.pub}  # this is a GITbash path
key=$(echo ${public_key} | awk -F'/' '{print $NF}')
read -p "Enter the name of your new Instance ["Demo-Cli-Instance"]: " instance_name
instance_name=${instance_name:-"Demo-Cli-Instance"}
 echo -----
 echo selected Instance name :${GREEN} $instance_name ${NC}
 echo selected public key:${GREEN} $public_key${NC}
 echo The Instance Type will be the most recent FreeTier Elligible :${GREEN} $inst_type${NC}
aws ec2 describe-instance-types --filters "Name=free-tier-eligible,Values=true" "Name=current-generation,Values=true" --query 'InstanceTypes[].{Instance:InstanceType,Memory:MemoryInfo.SizeInMiB,Ghz:ProcessorInfo.SustainedClockSpeedInGhz, VirType:SupportedVirtualizationTypes|[0]}'
echo
echo "********** Network ***********"
#################
# VPC 
#################
echo
while true; do
 aws ec2 describe-vpcs  --query   'Vpcs[].{VPCID:VpcId,association:CidrBlockAssociationSet[].CidrBlockState.State| [0],CIDR:CidrBlock,Name:Tags[?Key==`Name`].Value| [0]}'
 read -p "select the VPC Name for your new instance [$vpc_name]: " vpc_name
 vpc_name=${vpc_name:-$vpc_name}
 vpc_id=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=$vpc_name  --query   'Vpcs[].VpcId' --output text)
if [ -n "$vpc_id" ];
    then  
     echo selected VPC name :${GREEN} $vpc_name${NC}
     while true; do
     igw_id=$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$vpc_id --query 'InternetGateways[].InternetGatewayId' --output text) 
     if  [ -n "$igw_id" ];
     then echo 
     echo "${GREEN}1. Internet gateway exists => checking the subnet availability${NC}"
     echo ...
     break
     else echo " ${RED}No Internet Gateway is associated to $vpc_name VPC.${NC}";
     echo "${BLUE}creating and attaching the missing Internet gateway${NC}"
     igw_id=$(aws ec2 create-internet-gateway  --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=igw_$vpc_name}]" --query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' --output text  ) #--region $AWS_REGION
     aws ec2 attach-internet-gateway   --vpc-id $vpc_id  --internet-gateway-id $igw_id # --region $AWS_REGION
     fi
     done 
     break
else echo "${RED}The entered VPC name is not valid. Please retry or hit CTRL+C and create a new VPC using ./create_vpc.sh !${NC}"; 
 fi
 done
#################
# SUBNET 
#################
while true; do
sub_id=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].SubnetId' --output text)
if [ -n "$sub_id" ];
    then  
     aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[].{VPC_id:VpcId,SUB_id:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock,AutoIP:MapPublicIpOnLaunch,IP_COUNT:AvailableIpAddressCount,Name:Tags[?Key==`Name`].Value| [0]}' 
     read -p "Select The Subnet for your new instance [$sub_name]: " sub_name
     sub_name=${sub_name:-$sub_name}
     sub_id=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=$sub_name"  --query   'Subnets[].SubnetId' --output text)
     echo selected subnet name : ${GREEN} $sub_name ${NC} 
     if  [ -n "$sub_id" ];
     then echo
     echo " ${GREEN} Internet gateway and subnet exist => checking the Route table${NC}"
     echo ...
     break
     else echo " ${RED}The entered Subnet name doesn't exist for $vpc_name. Please choose another subnet or create a new subnet using ./create_subnet.sh first!${NC}";
     fi 
else echo "${RED}The entered VPC name has no subnet. Please choose another vpc or create a new subnet using create_subnet.sh first.${NC}"; 
exit 1
 fi 
done 
#################
# ROUTE 
#################
echo -e ...Route Table check
echo
 #ocid_ad=$(oci iam availability-domain list -c $C --query "data[0].name" --raw-output)
while true; do
rt_id=$(aws ec2 describe-route-tables  --filters "Name=tag:Name,Values=rt_$sub_name" "Name=route.gateway-id,Values=$igw_id" "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[].RouteTableId' --output text)
if [ -n "$rt_id" ];
then echo -e ${GREEN}The vpc has a route table with a route across an internet gateway. checking the association with $sub_name subnet. ${NC}
  echo -e ...
  asos_id=$(aws ec2 describe-route-tables --route-table-ids $rt_id --query "RouteTables[].Associations[?SubnetId =='$sub_id'].RouteTableAssociationId[]" --output text)
    if [ -n "$asos_id" ];
    then echo
    echo "2. Route is associated with $sub_name subnet. Checking the Security Group"
    echo  ...
    break
    else 
    echo " ${BLUE}... Creating missing Association between'$sub_name' Subnet and the Route Table.${NC}"
    aws ec2 associate-route-table --subnet-id $sub_id --route-table-id $rt_id 
    echo "2. Route is now associated with $sub_name subnet. Checking the Security Group"
    echo  ...
    fi
  break
else echo "${RED}The entered VPC name has no Route table with a path to Internet via an Internet gateway.${NC}"
    echo "${BLUE}creating the missing route table${NC}" 
rt_id=$(aws ec2 create-route-table   --vpc-id $vpc_id --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=rt_$sub_name}]" --query 'RouteTable.{RouteTableId:RouteTableId}' --output text )
echo "${BLUE} Create route to Internet Gateway for Route Table ID '$rt_id'.${NC}" 
aws ec2 create-route --route-table-id $rt_id --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id  #--region $AWS_REGION
fi
done        
#################
# Security Group
#################

  echo " ... ${GREEN} Checking the availability of a security Group with SSH/HTTP ingress rule .${NC}"
  sg_id=$(aws ec2 describe-security-groups --filter "Name=group-name,Values=sg_${vpc_name}" "Name=vpc-id,Values=$vpc_id"  --query 'SecurityGroups[].GroupId' --o text)
  while true; do
   if [ -n "$sg_id" ];
    then  ingress_exists=$(aws ec2 describe-security-groups --group-ids $sg_id --filter "Name=ip-permission.from-port,Values=22" "Name=group-name,Values=sg_${vpc_name}" "Name=vpc-id,Values=$vpc_id"  --query 'length(SecurityGroups[?IpPermissions[?ToPort==`80` && contains(IpRanges[].CidrIp, `0.0.0.0/0`)]])' --o text)
      if [ "$ingress_exists" = "0" ];
      then echo "Creating missing security Group Rules."
         sg_22=$(aws ec2 describe-security-groups --filter "Name=ip-permission.from-port,Values=22" "Name=vpc-id,Values=$vpc_id" "Name=ip-permission.cidr,Values='0.0.0.0/0'" --query SecurityGroups[].GroupId --output text)
         sg_443=$(aws ec2 describe-security-groups --filter "Name=ip-permission.from-port,Values=80" "Name=vpc-id,Values=$vpc_id" "Name=ip-permission.cidr,Values='0.0.0.0/0'" --query SecurityGroups[].GroupId --output text)
         sg_80=$(aws ec2 describe-security-groups --filter "Name=ip-permission.from-port,Values=443" "Name=vpc-id,Values=$vpc_id" "Name=ip-permission.cidr,Values='0.0.0.0/0'" --query SecurityGroups[].GroupId --output text)
           if [ -z "$sg_22" ];
           then echo "${BLUE}opening Port 22${NC}"
           aws ec2 authorize-security-group-ingress --group-id $sg_id --ip-permissions IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound SSH access"}]'
           fi
           if [ -z "$sg_80" ];
           then echo "${BLUE}opening Port 80${NC}"
           aws ec2 authorize-security-group-ingress --group-id $sg_id --ip-permissions IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound HTTP access "}]'
           fi
           if [ -z "$sg_443" ];
           then echo "${BLUE}opening Port 443${NC}"
           aws ec2 authorize-security-group-ingress --group-id $sg_id --ip-permissions IpProtocol=tcp,FromPort=433,ToPort=433,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound HTTPS access "}]'
           fi
      else  echo  "3. dedicated security Group ingress rules exists  PORT (22,80)."
         # Your current security groups don't have ports 3389 open
      fi
      break
    else echo "${BLUE}creating the missing dedicated security Group for the vpc${NC}"
    sg_id=$(aws ec2 create-security-group --group-name sg_$vpc_name --description "SSH ,HTTP, and HTTPS" --vpc-id $vpc_id --query GroupId --output text)
    fi
 done     
echo  "${GREEN}Creating the instance with the below SG .${NC}"  
aws ec2 describe-security-groups --filter "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=sg_${vpc_name}"  --query 'SecurityGroups[].{SG_id:GroupId,Name:GroupName,Vpc_id:VpcId,"Rules": IpPermissions[].{SourceCIDR:IpRanges[].CidrIp|[0],Description:IpRanges[].Description|[0],fromport:FromPort,ToPort:ToPort,Protocol:IpProtocol}}'  
#################
# AMIs
#################
echo "4. Choose your Image ||{**}||" 
echo
PS3='Select an option and press Enter: '
options=("RHEL" "CentOS" "amazon Linux 2" "Ubuntu" "Windows" "Suse" "Exit?")
select opt in "${options[@]}"
do
  case $opt in
        "RHEL")
          aws ec2 describe-images --owners 309956199498  --filters 'Name=name,Values=RHEL-7.?*GA*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          img_id=$(aws ec2 describe-images --owners 309956199498  --filters 'Name=name,Values=RHEL-7.?*GA*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text)
          userdata="--user-data file://cloud-init/el_userdata.txt"
          OS="REDEHAT"
          user="ec2-user"
          break
          ;;
        "CentOS")
          aws ec2 describe-images --owners 679593333241  --filters 'Name=name,Values=centos-7*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table 
          img_id=$(aws ec2 describe-images --owners 679593333241  --filters 'Name=name,Values=centos-7*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text) 
          userdata="--user-data file://cloud-init/el_userdata.txt"
          OS="CENTOS"
          user="centos"
          break
          ;;
          
        "amazon Linux 2")
          aws ec2 describe-images    --owners amazon  --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          img_id=$(aws ec2 describe-images    --owners amazon  --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text) 
          OS="amazon Linux 2"
          userdata="--user-data file://cloud-init/amzl_userdata.txt"
          user="ec2-user"
          break
          ;;
        "Ubuntu")
          aws ec2 describe-images  --owners 099720109477 --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-????????' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          img_id=$(aws ec2 describe-images  --owners 099720109477 --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-????????' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text)
          userdata="--user-data file://cloud-init/ubto_userdata.txt"
          OS="Ubuntu"
          user="ubuntu"
          break
          ;;
        "Windows")
          aws ec2 describe-images --owners 801119661308  --filters 'Name=name,Values=Windows_Server-*English-Full-Base*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          img_id=$(aws ec2 describe-images --owners 801119661308  --filters 'Name=name,Values=Windows_Server-*English-Full-Base*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text)
          userdata="--user-data file://cloud-init/Win_userdata.txt"
          OS="Windows"
          echo "${BLUE} opening port 3389 ${NC}"
          aws ec2 authorize-security-group-ingress --group-id $sg_id --ip-permissions IpProtocol=tcp,FromPort=3389,ToPort=3389,IpRanges='[{CidrIp=0.0.0.0/0,Description="Inbound RDP access "}]'
          break
          ;;
        "Suse")
          aws ec2 describe-images  --owners amazon  --filters 'Name=name,Values=suse-sles-*-v????????-hvm-ssd-x86_64' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          img_id=$(aws ec2 describe-images  --owners amazon  --filters 'Name=name,Values=suse-sles-*-v????????-hvm-ssd-x86_64' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text)
          userdata="--user-data file://cloud-init/sles_userdata.txt"
          OS="SUSE"
          user="ec2-user"
          break
          ;;          
        "Abort?")
          exit 
          ;;                              
        *) echo "invalid option";;
  esac
done
######################
# INSTANCE
######################
 echo =====${BLUE} Instance Deployment Detail${NC} ========
       echo
       echo selected Subnet name : ${GREEN}$sub_name${NC}
       echo selected Instance name : ${GREEN}$instance_name${NC}
       echo selected instance Type: ${GREEN}$inst_type${NC}
       echo selected public key: ${GREEN}$public_key${NC}
       echo selected Security Group: ${GREEN}$sg_id${NC}
       echo selected OS : ${GREEN}$OS${NC}
  echo ...
 echo Importing/checking the key pair to/from AWS   
  key_name=$(aws ec2 describe-key-pairs --filters "Name=key-name,Values=${key}_KeyPair" --query 'KeyPairs[].KeyName' --output text)
  if [ -z "$key_name" ];
  then
  aws ec2 import-key-pair --key-name "${key}_KeyPair" --public-key-material fileb://$public_key
  # ssh-keygen -y -f MyKeyPair.pem > $HOME/.ssh/id_rsa_MyKeyPair.pub
  else echo key-pair exists ..
    fi     
# run the below which will launch the instance and store the instance_id in a variable 
instance_id=$(aws ec2 run-instances --image-id $img_id --instance-type $inst_type --count 1 --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" --subnet-id $sub_id --key-name ${key}_KeyPair --security-group-ids $sg_id $userdata --query 'Instances[].InstanceId' --output text)  
echo
echo ====================================
echo Check the status of the new Instance
echo ====================================
echo The compute instance is being created. This will take few minutes ... 
aws ec2 wait instance-running --instance-ids $instance_id
aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[].Instances[].{ID: InstanceId,VPCID:VpcId,Subnet:SubnetId,image:ImageId,status:State.Name,Hostname: PublicDnsName,AZ:Placement.AvailabilityZone,PrivIP:PrivateIpAddress,Public_IP:PublicIpAddress,Type: InstanceType,Name:Tags[?Key==`Name`].Value| [0],Platform: Platform }' --output table  
pub_ip=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[].Instances[].PublicIpAddress' --output text)
echo
if [[ "$OS" == "Windows" ]];
then 
echo "${BLUE}Password is being generated... please wait${NC}"
aws ec2 wait password-data-available --instance-id $instance_id
echo  "RDP connection to the instance ==> use an RDP session (MSTSC) from your windows machine to connect to the instance"
password=$(aws ec2 get-password-data --instance-id  $instance_id --priv-launch-key ~/id_rsa_aws --query [PasswordData] --o text) 
echo "Windows User = ${GREEN}Administrator${NC} "
echo "Password     => ${GREEN}$password${NC} "
echo "The generated password can be retreived few minutes later using : aws ec2 get-password-data --instance-id $instance_id --priv-launch-key ~/id_rsa_aws"
else
echo "ssh connection to the instance ==> sudo ssh -i ~/id_rsa_aws ${user}@${pub_ip}" # if private-key is in the same path as the public-key use: echo ${public_key} | awk -F. '{print $1}'
fi
 echo "${BLUE} Your website is ready at this IP :) :${GREEN} http://${pub_ip} ${NC} "
echo "termination command ==>${RED} aws ec2 terminate-instances --instance-ids $instance_id ${NC}" 
 
