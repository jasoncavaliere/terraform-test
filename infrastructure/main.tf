terraform {
  required_version = ">= 0.12"
  backend "azurerm" {
	#resource group for state storage
    resource_group_name  	= "rg-inf-terraform"
	# stroage instance for state
    storage_account_name 	= "terraformstate32"
	#Storage container name for state
    container_name       	= "terraform"
	#key in container for state
    key                  	= "terraform-getting-started.tfstate"
	#disable prompts when external variables are missing
	TF_INPUT				= 0
  }
}

variable "subscription_Id" {
  type        = string
  description = "The Azure subscriptionId for resources."
}
variable "tenant_Id" {
  type        = string
  description = "The Azure tenant ID for resources."
}

# Configure the Azure provider
provider "azurerm" {
    version = "=1.41.0"
	subscription_id = var.subscription_Id
}

locals{
	subscriptionName 	= "JasonC"
	tenantId			= var.tenant_Id
	region 				= "usc"
	regionName 			= "South Central US"
	location 			= "southcentralus"
	tenant 				= "sh"
	tenantName 			= "Shared"
	env 				= "dev"
	envName 			= "Dev"
	role 				= "insights"
	roleName 			= "Insights"

}


locals{
	#resource Group
	insightsResourceGroupName 	= "rg-${local.tenant}-${local.env}-${local.region}-${local.role}"

	# Storage Account
	insightsStorageAccountName 	= "${local.tenant}${local.env}${local.region}${local.role}"
	insightsStorageAccountTier  = "Standard"
	insightsStorageAccountType  = "GRS"
	insightsStorageAccountSku 	= "Standard_GRS"
	insightsStorageAccountKind 	= "StorageV2"

	# Key Vault
	insightsKeyVaultName 		= "kv-${local.tenant}-${local.env}-${local.region}-${local.role}"
	
	# Application Insights
	insightsApplicationInsightsName = "ai-${local.tenant}-${local.env}-${local.region}-${local.role}"
	insightsApplicationType			= "web"
	
	
	# Machine Learning
	insightsMachineLearningWorkspaceName 							= "mlw-${local.tenant}-${local.env}-${local.region}-${local.role}"
	insightsMachineLearningWorkspaceFriendlyName 					= "Laso ${local.roleName}"
	insightsMachineLearningWorkspaceSku 							= "Enterprise"
	insightsMachineLearningWorkspaceIncomingDatastoreName 			= "${local.role}-incoming-datastore"
	insightsMachineLearningWorkspaceIncomingDatastoreFriendlyName 	= "insightsincoming"
	
}



# Create a new resource group
resource "azurerm_resource_group" "insightsgroup" {
    name     				= local.insightsResourceGroupName
    location 				= local.regionName
}

resource "azurerm_storage_account" "insights-storage" {
  name                		= local.insightsStorageAccountName
  resource_group_name 		= azurerm_resource_group.insightsgroup.name
  location 					= local.regionName
  account_tier				= local.insightsStorageAccountTier
  account_replication_type	= local.insightsStorageAccountType
}

resource "azurerm_storage_container" "insights-storagecontainer" {
  name                  	= local.insightsMachineLearningWorkspaceIncomingDatastoreName
  storage_account_name  	= azurerm_storage_account.insights-storage.name
  container_access_type 	= "blob"
}

resource "azurerm_key_vault" "insignts-kvs" {
	name 					= local.insightsKeyVaultName
	location 				= local.regionName
	resource_group_name 	= azurerm_resource_group.insightsgroup.name
	tenant_id				= local.tenantId
	sku_name				= "standard"
	tags 					= {
								Tenant=local.tenantName
								Role=local.roleName
								Environment= local.envName
							}
}

resource "azurerm_application_insights" "insights-insights" {
	name                	= local.insightsApplicationInsightsName
	location 				= local.regionName
	resource_group_name 	= azurerm_resource_group.insightsgroup.name
	application_type    	= local.insightsApplicationType 
}

resource "null_resource" "ml-workspace-dependencies" {
	provisioner "local-exec" {
		command = "az extension add -n azure-cli-ml"  
	}
}



#-w workspace-Name
#-f --friendly-name 
#-g --resource-group
#-l --location
resource "null_resource" "create-ml-workspace" {
	depends_on=[null_resource.ml-workspace-dependencies]
	provisioner "local-exec" {
		interpreter =["PowerShell"]
		command ="az ml workspace create -w ${local.insightsMachineLearningWorkspaceName} -f \"${local.insightsMachineLearningWorkspaceFriendlyName}\" -g \"${azurerm_resource_group.insightsgroup.name}\" --storage-account \"/subscriptions/${var.subscription_Id}/resourceGroups/${azurerm_resource_group.insightsgroup.name}/providers/Microsoft.Storage/storageAccounts/${local.insightsStorageAccountName}\"  --keyvault \"/subscriptions/${var.subscription_Id}/resourceGroups/${azurerm_resource_group.insightsgroup.name}/providers/Microsoft.KeyVault/vaults/${local.insightsKeyVaultName}\"  --application-insights \"/subscriptions/${var.subscription_Id}/resourceGroups/${azurerm_resource_group.insightsgroup.name}/providers/Microsoft.Insights/components/${local.insightsApplicationInsightsName}\"  -l \"${local.regionName}\"  --sku \"${local.insightsMachineLearningWorkspaceSku}\""
  }
}


resource "null_resource" "attach-ml-folder" {
	depends_on=[null_resource.create-ml-workspace]
	provisioner "local-exec" {
		command ="az ml folder attach --workspace-name ${local.insightsMachineLearningWorkspaceName} --resource-group ${local.insightsResourceGroupName}"
  }
}









































