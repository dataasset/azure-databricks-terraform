#Create Azure Ad groups
module "azure_ad_groups" {
  source = "./modules/ad_groups"  # Path to the module
  group_name = ["Data_Analyst", "Data_Engineer"]
}

locals {
  prefix = var.prefix
  account_id = var.account_id
  scim_token = var.scim_token
  aad_groups = toset(["Data_Analyst", "Data_Engineer"])
}


#Create Dev Resource Group
module "rg" {
  source = "./modules/resource_groups"
  resource_name = "rg-${local.prefix}"
  location = "East US"
}

#Create Azure db_workspace
module "workspace" {
    depends_on = [module.rg]
    source = "./modules/db_workspaces"
    rg_name = module.rg.rg_name
    managed_rg_name = "rg-managed-dbx-${local.prefix}"
    resource_name = "dbx_workspace_${local.prefix}"
    location = module.rg.rg_location
}

// Create a storage account to be used by unity catalog metastore as root storage
module "unity_catalog" {
    depends_on = [module.rg]
    source = "./modules/storage_accounts"
    resource_name = "storageaccdbxuc${local.prefix}"
    rg_name = module.rg.rg_name
    location = module.rg.rg_location
}

// Create a container in storage account to be used by unity catalog metastore as root storage
module "unity_catalog_container" {
    depends_on = [module.unity_catalog]
    source = "./modules/storage_containers"
    container_name = "uc-container-${local.prefix}"
    storage_account_name = module.unity_catalog.name
}

provider "databricks" {
  host = module.workspace.workspace_url
}

// Provider for databricks account
provider "databricks" {
    alias = "azure_account"
    host  = "https://accounts.azuredatabricks.net"
    account_id = local.account_id
    auth_type  = "azure-cli"
}

data "databricks_current_user" "me" {}

// Create azure managed identity to be used by unity catalog metastore
// Assign the Storage Blob Data Contributor role to managed identity to allow unity catalog to access the storage
// Create unity catalog metastore and Assign managed identity to metastore and Attach the databricks workspace to the metastore
module "uc_metastore" {
    depends_on = [module.workspace]
    source = "./modules/uc_metastore"
    access_connector_name = "databricks-mi-${local.prefix}"
    resource_group_name = module.rg.rg_name
    resource_group_location = module.rg.rg_location
    catalog_id = module.unity_catalog.id
    container_name = module.unity_catalog_container.name
    storage_account_name = module.unity_catalog.name
    workspace_id = module.workspace.workspace_id
    metastore_name = "metastore-${local.prefix}"
}

//Get Enterprise application for databricks
data "azuread_application_template" "scim" {
  display_name = "Azure Databricks SCIM Provisioning Connector"
}

// Random UUID for the application role
resource "random_uuid" "uuid" {}

# //Enterprise application
resource "azuread_application" "scim" {
  display_name = "dbx-scim-${local.prefix}"
  template_id  = data.azuread_application_template.scim.template_id

  app_role {
    allowed_member_types = ["Application", "User"]
    description          = "Users can perform limited actions"
    display_name         = "User"
    enabled              = true
    id                   = random_uuid.uuid.result
    value                = "User"
  }
}

// SCIM SPA
data "azuread_service_principal" "scim" {
  application_id = azuread_application.scim.application_id
}

// Add SCIM groups to the application
resource "azuread_app_role_assignment" "scim" {
  for_each            = module.azure_ad_groups.ad_groups
  app_role_id         = data.azuread_service_principal.scim.app_role_ids["User"]
  principal_object_id = each.key
  resource_object_id  = data.azuread_service_principal.scim.object_id
}

// Synchronization job ( Provisioner in Azure AD application)
resource "azuread_synchronization_secret" "synchronization" {
  service_principal_id = data.azuread_service_principal.scim.id

  credential {
    key   = "BaseAddress"
    value = "https://accounts.azuredatabricks.net/api/2.1/accounts/${local.account_id}/scim/v2"
  }

  credential {
    key   = "SecretToken"
    value = local.scim_token
  }

  credential {
    key   = "SyncAll"
    value = "false"
  }
}

// Creat sync job
resource "azuread_synchronization_job" "sync_job" {
  service_principal_id = data.azuread_service_principal.scim.id
  template_id          = "dataBricks"
  enabled              = true
}


// Create a container in storage account to be used by dev catalog as root storage
module "dev_catalog_container" {
    depends_on = [module.unity_catalog]
    source = "./modules/storage_containers"
    container_name = "catalog-${local.prefix}"
    storage_account_name = module.unity_catalog.name
}

// Storage credential creation to be used to create external location
resource "databricks_storage_credential" "external_mi" {
    name = "external-storage-credential-${local.prefix}"
    azure_managed_identity {
        access_connector_id = module.uc_metastore.access_connector_id
        }
    comment = "Storage credential for all external locations"
    depends_on = [module.dev_catalog_container]
}

data "databricks_group" "groups" {
  provider = databricks.azure_account
  for_each = local.aad_groups 
  display_name = each.key
}

resource "databricks_mws_permission_assignment" "workspace_user_groups" {
    for_each =  { for k, v in data.databricks_group.groups : k => v.id } 
    provider = databricks.azure_account
    workspace_id = module.workspace.workspace_id
    principal_id = each.value
    permissions  = ["USER"]
    depends_on   = [data.databricks_group.groups]
}

// Create external location to be used as root storage by dev catalog and Create dev environment catalog
module "dev_catalog" {
    depends_on = [databricks_storage_credential.external_mi]
    source = "./modules/catalog_setup"
    external_location_name = "external-location-${local.prefix}"
    storage_account_name = module.unity_catalog.name
    storage_container_name = module.dev_catalog_container.name
    storage_credential_id = databricks_storage_credential.external_mi.id
    catalog_name = "catalog-${local.prefix}"
    metastore_id = module.uc_metastore.metastore_id
    principals_and_privileges = [
        {
            name = "Data_Engineer"
            privileges = ["USE_CATALOG", "CREATE_SCHEMA"]
        },
        {
            name = "Data_Analyst"
            privileges = ["USE_CATALOG"]
        }
    ]
}

// Create schema for bronze datalake layer in dev env.
module "bronze_schema" {
    depends_on = [module.dev_catalog]
    source = "./modules/schema_setup"
    catalog_id = module.dev_catalog.catalog_id
    schema_name = "bronze"
    principals_and_privileges = [
        {
            name = "Data_Engineer"
            privileges = ["USE_SCHEMA","CREATE_TABLE", "SELECT", "CREATE_FUNCTION"]
        },
        {
            name = "Data_Analyst"
            privileges = ["USE_SCHEMA", "SELECT"]
        }
    ]
}

// Create schema for silver datalake layer in env.
module "silver_schema" {
    depends_on = [module.dev_catalog]
    source = "./modules/schema_setup"
    catalog_id = module.dev_catalog.catalog_id
    schema_name = "silver"
    principals_and_privileges = [
        {
            name = "Data_Engineer"
            privileges = ["USE_SCHEMA","CREATE_TABLE", "SELECT", "CREATE_FUNCTION"]
        },
        {
            name = "Data_Analyst"
            privileges = ["USE_SCHEMA","CREATE_TABLE", "SELECT"]
        }
    ]
}

// Create schema for gold datalake layer in env.
module "gold_schema" {
    depends_on = [module.dev_catalog]
    source = "./modules/schema_setup"
    catalog_id = module.dev_catalog.catalog_id
    schema_name = "gold"
    principals_and_privileges = [
        {
            name = "Data_Engineer"
            privileges = ["USE_SCHEMA","CREATE_TABLE", "SELECT", "CREATE_FUNCTION"]
        },
        {
            name = "Data_Analyst"
            privileges = ["USE_SCHEMA","CREATE_TABLE", "SELECT"]
        }
    ]
}
