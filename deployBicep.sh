#!/bin/bash
# Sample usage ./deployBicep.sh -s sample-subscription -m MIN02 -r RG20
# If subscription is ommited then it is set with the same value used for ministry (-m) ./deployBicep.sh -m MIN02 -r RG20

red='\e[1;31m%s\e[0m\n'
green='\e[1;32m%s\e[0m\n'
blue='\e[1;34m%s\e[0m\n'

SUBSCRIPTION=''
AGENCY=''
PROJECT=''

while getopts 's:m:r:' flag; 
do
  case "${flag}" in
    s) SUBSCRIPTION=${OPTARG} ;;  
    m) AGENCY=${OPTARG} ;;
    r) PROJECT=${OPTARG} ;;
  esac
done

if [[ -z $SUBSCRIPTION ]]; then
  SUBSCRIPTION=$AGENCY
fi

cd apps/$AGENCY/$PROJECT

#Get environment parameters from bicep param file
PARAM_FILE="./deploy.bicepparam"

printf "$blue" "*** Getting the needed values for the deployment from parameter file ***"

# Get the location from the bicep param file
# LOCATION=$(grep -E "param\s+location\s*=" deploy.bicepparam | awk -F"'" '{print $2}')
# Get the agency from the bicep param file
# AGENCY=$(grep -E "param\s+agency\s*=" deploy.bicepparam | awk -F"'" '{print $2}')
# Get the project from the bicep param file
# PROJECT=$(grep -E "param\s+project\s*=" deploy.bicepparam | awk -F"'" '{print $2}')

# # #  Set the right subscription
printf "$blue" "*** Setting the subsription to $SUBSCRIPTION ***"

# az account set --name "$SUBSCRIPTION"

################################################
# Temporary hardcoded subscription for testing  #
################################################
az account set --name "ME-MngEnvMCAP224983-kfotiadou-1"

# Get the current date
current_date=$(date +'%m-%d-%Y')

# Get the project request number from the bicep param file
REQUESTNUMBER=$(grep -E "var\s+requestNumber\s*=" deploy.bicepparam | awk -F"'" '{print $2}')

# Get the subscription id based on the name

# SUBSCRIPTION_ID=$(az account show --subscription $SUBSCRIPTION --query id -o tsv)
################################################
# Temporary hardcoded subscription for testing  # 
SUBSCRIPTION_ID=$(az account show --subscription "ME-MngEnvMCAP224983-kfotiadou-1" --query id -o tsv)
################################################

# Update the resource group tags
printf "$blue" "*** Updating resource group tags on $AGENCY-$PROJECT ***"

# TAG_OUTPUTS=$(az tag update --operation merge --resource-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$AGENCY-$PROJECT" --tags "Αρ.Αιτήματος=$REQUESTNUMBER" "Creation Date=$current_date") 
#################################################
# Temporary hardcoded subscription for testing
TAG_OUTPUTS=$(az tag update --operation merge --resource-id "/subscriptions/6a450bf1-e243-4036-8210-822c2b95d3ad/resourceGroups/$AGENCY-$PROJECT" --tags "Αρ.Αιτήματος=$REQUESTNUMBER" "Creation Date=$current_date") 
#################################################

if [[ -z $TAG_OUTPUTS ]]; then 
    printf "$red" "*** Resource group tags update failed! ***"
else
    printf "$green" "*** Resource group tags update completed! ***"
fi

# start the BICEP deployment

printf "$blue" "*** Starting BICEP deployment for $AGENCY-$PROJECT on $SUBSCRIPTION ***"

DEPLOYMENT_OUTPUTS=$(az deployment group create \
--name "$AGENCY"-"$PROJECT" \
--resource-group "$AGENCY"-"$PROJECT" \
--parameters "$PARAM_FILE" )

vnetName=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.properties.outputs.vnetName.value')
nsgSubnets=$(echo $DEPLOYMENT_OUTPUTS | jq -r '.properties.outputs.nsgSubnets.value')

# delegate NSGs to Subnets

echo "Subnets without delegation: $nsgSubnets"

if [[ -z $DEPLOYMENT_OUTPUTS ]]; then 
    printf "$red" "*** BICEP deployment failed! ***"
    exit 1
else
    printf "$green" "*** BICEP deployment completed! ***"

    printf "$blue" "*** Updating subnets with respective nsgs ***"
    for subnet in $(echo "$nsgSubnets" | jq -c '.[]');
    do
      subnetName=$(echo "$subnet" | jq -r '.subNetName')
      echo "Subnet name: $subnetName"
      nsgName=$(echo "$subnet" | jq -r '.nsgName')
      echo "NSG name: $nsgName"
      az network vnet subnet update -g $AGENCY-$PROJECT -n $subnetName --vnet-name $vnetName --network-security-group $nsgName
    done

    printf "$green" "*** NSG assignment to subnets completed! ***"
fi
