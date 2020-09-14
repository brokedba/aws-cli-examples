#!/bin/bash
# Author Brokedba https://twitter.com/BrokeDba
RED=$'\e\033[0;31m'
GREEN=$'\e\033[0;32m'
BLUE=$'\e\033[1;34m'
NC=$'\e\033[0m' # No Color
echo "******* amazon Image Selecta ! ************"
echo "Choose your Destiny ||{**}||${GREEN} " 
echo 
PS3='Select an option and press Enter: '
options=("RHEL" "CentOS" "amazon Linux 2" "Ubuntu" "Windows" "Suse" "Exit?")
select opt in "${options[@]}"
do 
  case $opt in
        "RHEL")
          aws ec2 describe-images --owners 309956199498  --filters 'Name=name,Values=RHEL-8.*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          aws ec2 describe-images --owners 309956199498  --filters 'Name=name,Values=RHEL-7.*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          ;;
        "CentOS")
          aws ec2 describe-images --owners 679593333241  --filters 'Name=name,Values=centos-8*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table 
          aws ec2 describe-images --owners 679593333241  --filters 'Name=name,Values=centos-7*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table 
          break
          ;;
          
        "amazon Linux 2")
          aws ec2 describe-images    --owners amazon  --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????.?-x86_64-gp2' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          ;;
        "Ubuntu")
          aws ec2 describe-images  --owners 099720109477 --filters 'Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-????????' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          ;;
        "Windows")
          aws ec2 describe-images --owners 801119661308  --filters 'Name=name,Values=Windows_Server-*English-Full-Base*' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          ;;
        "Suse")
          aws ec2 describe-images  --owners amazon  --filters 'Name=name,Values=suse-sles-*-v????????-hvm-ssd-x86_64' 'Name=state,Values=available' --query 'reverse(sort_by(Images, &CreationDate))[:1].{Name:Name,Ami:ImageId,Created:CreationDate,SizeGb:BlockDeviceMappings[:1].Ebs.VolumeSize|[0]}' --output table
          ;;          
        "Exit?")
          exit 
          ;;                              
        *) echo "invalid option";;
  esac
done 
echo "*********************"
#ocid_img=$(oci compute image list -c $C --operating-system "Oracle Linux" --operating-system-version "7.8" --shape "VM.Standard2.1"   --query 'data[0].id'  --raw-output)
