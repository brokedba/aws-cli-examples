#!/bin/bash
# Author Brokedba https://twitter.com/BrokeDba
echo "******* Oci instance launch ! ************"
echo "Choose your Shape ||{**}||" 
echo
RED=$'\e\033[0;31m'
GREEN=$'\e\033[0;32m'
BLUE=$'\e\033[1;34m'
NC=$'\e\033[0m' # No Color
echo -e "Note: ${RED} t2.Micro${GREEN} is the default FreeTier elligible instance type used here ${BLUE}[Default option =Micro compute]${NC}"
#read -p "Enter the Shape name you wish to create [VM.Standard.E2.1.Micro]: " shape
inst_type=$(aws ec2 describe-instance-types --filters "Name=free-tier-eligible,Values=true" "Name=current-generation,Values=true" --query 'InstanceTypes[].InstanceType' --output text)

read -p "Enter the Path of your ssh key [/c/Users/brokedba/oci/.ssh/id_rsa.pub]: " public_key
public_key=${public_key:-/mnt/c/oracle/oci/.ssh/id_rsa.pub}  # this is a GITbash path
read -p "Enter the name of your new Instance ["Demo-Cli-Instance"]: " instance_name
instance_name=${instance_name:-"Demo-Cli-Instance"}
 echo selected Instance name :${GREEN} $instance_name ${NC}
 echo selected public key:${GREEN} $public_key${NC}
 echo The Instance Type will be the most recent FreeTier Elligible :${GREEN} $inst_type${NC}
aws ec2 describe-instance-types --filters "Name=free-tier-eligible,Values=true" "Name=current-generation,Values=true" --query 'InstanceTypes[].{Instance:InstanceType,Memory:MemoryInfo.SizeInMiB,Ghz:ProcessorInfo.SustainedClockSpeedInGhz, VirType:SupportedVirtualizationTypes|[0]}'
echo
echo "Choose your Image ||{**}||" 
echo
PS3='Select an option and press Enter: '
options=("RHEL" "CentOS" "amazon Linux 2" "Ubuntu" "Windows" "Suse" "Exit?")
select opt in "${options[@]}"
do
  case $opt in
        "RHEL")
          aws ec2 describe-images --owners 309956199498  --filters 'Name=name,Values=RHEL-7.?*GA*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          img_id=$(aws ec2 describe-images --owners 309956199498  --filters 'Name=name,Values=RHEL-7.?*GA*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text)
          break
          ;;
        "CentOS")
          aws ec2 describe-images --owners 679593333241  --filters 'Name=name,Values=centos-7*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table 
          img_id=$(aws ec2 describe-images --owners 679593333241  --filters 'Name=name,Values=centos-7*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text) 
          break
          ;;
          
        "amazon Linux 2")
          aws ec2 describe-images    --owners amazon  --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          img_id=$(aws ec2 describe-images    --owners amazon  --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text) 
          break
          ;;
        "Ubuntu")
          aws ec2 describe-images  --owners 099720109477 --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-????????' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          img_id=$(aws ec2 describe-images  --owners 099720109477 --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-????????' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text)
          break
          ;;
        "Windows")
          aws ec2 describe-images --owners 801119661308  --filters 'Name=name,Values=Windows_Server-*English-Full-Base*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          img_id=$(aws ec2 describe-images --owners 801119661308  --filters 'Name=name,Values=Windows_Server-*English-Full-Base*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text)
          break
          ;;
        "Suse")
          aws ec2 describe-images  --owners amazon  --filters 'Name=name,Values=suse-sles-*-v????????-hvm-ssd-x86_64' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          img_id=$(aws ec2 describe-images  --owners amazon  --filters 'Name=name,Values=suse-sles-*-v????????-hvm-ssd-x86_64' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].ImageId' --output text)
          break
          ;;          
        "Abort?")
          exit 
          ;;                              
        *) echo "invalid option";;
  esac
done
echo "********** Network ***********"
echo
while true; do
 aws ec2 describe-vpcs  --query   'Vpcs[].{VPCID:VpcId,association:CidrBlockAssociationSet[].CidrBlockState.State| [0],CIDR:CidrBlock,Name:Tags[?Key==`Name`].Value| [0]}'
 read -p "select the VPC Name for your new instance [$vpc_name]: " vpc_name
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
     read -p "Select The Subnet for your new instance [$sub_name]: " sub_name
     sub_name=${sub_name:-$sub_name}
     sub_id=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" "Name=tag:Name,Values=$sub_name"  --query   'Subnets[].SubnetId' --output text)
     echo selected subnet name : ${GREEN} $sub_name ${NC} 
     if  [ -n "$sub_id" ];
     then echo
     echo " ${GREEN}Internet gateway and subnet exist => checking the Route table${NC}"
     echo ...
     break
     else echo " ${RED}The entered Subnet name doesn't exist for $vpc_name. Please retry!${NC}";
     fi 
else echo "${RED}The entered VPC name has no subnet. Please choose another vpc or create a new subnet using create_subnet.sh first.${NC}"; 
exit 1
 fi 
done 
echo -e ...Route Table check
echo
 #ocid_ad=$(oci iam availability-domain list -c $C --query "data[0].name" --raw-output)

rt_id=$(aws ec2 describe-route-tables  --filters "Name=route.gateway-id,Values=igw-0556f0219841b61c9" "Name=vpc-id,Values=vpc-096b461ebe9d06ff3" --query 'RouteTables[].RouteTableId' --output text)
if [ -n "$rt_id" ];
  then echo -e ${GREEN}The vpc has a route table with a route across an internet gateway. checking the association with $sub_name subnet. ${NC}
  echo -e ...
  while true; do
  asos_id=$(aws ec2 describe-route-tables --query "RouteTables[].Associations[?SubnetId =='$sub_id'].RouteTableAssociationId[]" --output text)
  if [ -n "$asos_id" ];
  then echo
  echo Route is associated with $sub_name subnet. Checking the Security Group
  echo -e ...
  break
  else 
  echo " ... ${GREEN} Creating missing Association between'$sub_name' Subnet and the Route Table.${NC}"
  aws ec2 associate-route-table --subnet-id $sub_id --route-table-id $rt_id 
  fi
  done 
else echo "${RED}The entered VPC name has no Route table with a path to Internet via an Internet gateway. 
        > Please Enter Yes to Create an instance without Internet Access or No to exit and Create/attach an Internet Gateway to your Route Table (create_igateway.sh) .${NC}"; 
read -r -p "Would you like to Continue? [y/N] " response
  case "$response" in
      [yY][eE][sS]|[yY]) 
          echo ...
          ;;
      *)
          exit 1
          ;;
  esac
fi
  echo " ... ${GREEN} Checking the availability of a security Group with at least SSH ingress rule .${NC}"
  sg_id=$(aws ec2 describe-security-groups --filter "Name=ip-permission.from-port,Values=22" "Name=vpc-id,Values=$vpc_id"  --query SecurityGroups[].GroupId --output text) #
  if [ -n "$sg_id" ];
  then echo security the Group exists . Creating the instance with the below SG  
  aws ec2 describe-security-groups --filter "Name=ip-permission.from-port,Values=22" "Name=vpc-id,Values=$vpc_id"  --query 'SecurityGroups[].{SG_id:GroupId,Name:GroupName,Vpc_id:VpcId,"Rules": IpPermissions[].{SourceCIDR:IpRanges[].CidrIp|[0],Description:IpRanges[].Description|[0],fromport:FromPort,ToPort:ToPort,Protocol:IpProtocol}}'
  else
  echo  No security Group with at least SSH ingress rule ports available > Please Enter Yes to Create an instance without SG or No to exit 
  
  read -r -p "Would you like to Continue? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo Creating the instance without the SSH port open ...
          echo ===== Instance Deployment Detail ========
          echo selected Subnet name : $sub_name
          echo selected Instance name : $instance_name
          echo selected instance Type: $inst_type
          echo selected public key: $public_key 
          echo ...
          echo Importing/checking the key pair to AWS   
          key_name=$(aws ec2 describe-key-pairs --filters "Name=key-name,Values=${instance_name}_KeyPair" --query 'KeyPairs[].KeyName' --output text)
          if [ -z "$sg_id" ];
          then
          aws ec2 import-key-pair --key-name "${instance_name}_KeyPair" --public-key-material fileb://$public_key
          # ssh-keygen -y -f MyKeyPair.pem > $HOME/.ssh/id_rsa_MyKeyPair.pub
          else echo key-pair exists ..
          fi
          instance_id=$(aws ec2 run-instances --image-id $img_id --instance-type $inst_type --count 1 --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" --subnet-id $sub_id --key-name ${instance_name}_MyKeyPair --query 'Instances[].InstanceId' --output text) 
          aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[].Instances[].{ID: InstanceId,VPCID:VpcId,Subnet:SubnetId,image:ImageId,status:State.Name,Hostname: PublicDnsName,AZ:Placement.AvailabilityZone,PrivIP:PrivateIpAddress,Public_IP:PublicIpAddress,Type: InstanceType,Name:Tags[?Key==`Name`].Value| [0],Platform: Platform }' --output table   
          exit 
            ;;
        *)
            exit 1
            ;;
  esac #aws ec2 describe-route-tables  --route-table-id $rt_id --query 'RouteTables[*].{rt_id:RouteTableId,Vpc_id:VpcId, Main:Associations[].Main| [0],Routes:Routes,Name:Tags[?Key==`Name`].Value| [0]}'
 fi
 echo ===== Instance Deployment Detail ========
       echo selected Subnet name : $sub_name
       echo selected Instance name : $instance_name
       echo selected instance Type: $inst_type
       echo selected public key: $public_key
       echo selected Security Group: $sg_id
  echo ...
 echo Importing/checking the key pair to AWS   
  key_name=$(aws ec2 describe-key-pairs --filters "Name=key-name,Values=${instance_name}_KeyPair" --query 'KeyPairs[].KeyName' --output text)
  if [ -z "$sg_id" ];
  then
  aws ec2 import-key-pair --key-name "${instance_name}_KeyPair" --public-key-material fileb://$public_key
  # ssh-keygen -y -f MyKeyPair.pem > $HOME/.ssh/id_rsa_MyKeyPair.pub
  else echo key-pair exists ..
  instance_id=$(aws ec2 run-instances --image-id $img_id --instance-type $inst_type --count 1 --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" --subnet-id $sub_id --key-name ${instance_name}_KeyPair --security-group-ids $sg_id --user-data file://vm_userdata.txt --query 'Instances[].InstanceId' --output text)  
  fi     
# run the below which will launch the instance and store the instance_id in a variable 

echo
echo ====================================
echo Check the status of the new Instance
echo ====================================
echo The compute instance is being created will take few minutes ... 
aws ec2 wait instance-running --instance-ids $instance_id
aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[].Instances[].{ID: InstanceId,VPCID:VpcId,Subnet:SubnetId,image:ImageId,status:State.Name,Hostname: PublicDnsName,AZ:Placement.AvailabilityZone,PrivIP:PrivateIpAddress,Public_IP:PublicIpAddress,Type: InstanceType,Name:Tags[?Key==`Name`].Value| [0],Platform: Platform }' --output table  
pub_ip=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[].Instances[].PublicIpAddress' --output text)
echo
echo "ssh connection to the instance ==> sudo ssh -i ~/id_rsa centos@${pub_ip}"
echo "termination command ==>${RED} aws ec2 terminate-instances --instance-ids $instance_id ${NC}" 
 