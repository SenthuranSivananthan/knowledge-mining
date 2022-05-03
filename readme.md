# Introduction

The implementation in this repository is based [Knowledge Mining Solution Accelerator](https://docs.microsoft.com/en-us/samples/azure-samples/azure-search-knowledge-mining/azure-search-knowledge-mining/).

This repository aims to simplify the onboarding experience through automation.  Therefore, the following changes/additions have been made to the original solution:

1. Converted the ARM templates to [Bicep](https://github.com/Azure/bicep) templates for easier Infrastructure as Code authoring experience.

2. Scripted the Azure Search Index creation through bash to avoid any manual steps through Postman or REST APIs.

3. Scripted deployment using Azure DevOps Pipelines for push-button deployment.

# Azure Services

The solution uses 5 Azure PaaS Services:

1. **Azure App Service** - Hosting environment for the .NET Core Web Application
2. **Azure Cognitive Services** - Built-in Machine Learning capabilities to extract insights from documents, images, etc.
3. **Azure Search** - Search index to explore the insights
4. **Azure Key Vault** - Secrets & key management
5. **Azure Storage Account** - Document repository

# Service Principal Account

Automated deployment will require one Service Principal Account.  This account is used for:

1. Deploying the Azure Infrastructure
2. Integrating with Azure Key Vault for key management

The service principal account will need `Owner` Role assigned (IAM) at the Subscription.  This configuration will allow multiple deployment of the same solution in the same subscription.

Once the service principal is created, document the following information in a secure place:

1. Enterprise Application Object Id
2. Application Id
3. Application Secret
4. Tenant Id

# Configure Azure DevOps Pipeline

All Azure DevOps pipeline will use the service principal to interact with Azure.

## Configure Service Connection

1. Navigate to `Project Settings`
2. Navigate to Pipelines -> `Service Connections`
3. Click on `New Service Connection`
4. Click on `Azure Resource Manager`, Click Next
5. Click on `Service Principal (manual)`, Click Next
6. Ensure Environment is set to `Azure Cloud`
7. Ensure Scope Level is set to `Subscription`
8. Enter the `Subscription Id` for your subscription
9. Enter a Name for the Subscription
10.  Enter Application Id of the Service Principal in `Service Principal Id`
11.  Enter Application Secret of the Service Principal in `Service Principal Key`
12.  Enter `Tenant Id`
13.  Click Verify to validate the connection.  This step will ensure that the Service Principal Account has the required permissions to subscriptoin.
14. Enter `Service connection name`.  This will be used in the Azure Pipelines to reference the connection information.  i.e. `azure-knowledge-mining-arm-connection`
15. Ensure `Grant access permission to all pipelines` is checked
16. Click `Verify and Save`

## Configure 3 DevOps Pipelines

The Service Connection that was setup earlier will be used in each of the pipelines.  The pipeline YAMLs have `azure-knowledge-mining-arm-connection` as the reference to the connection.  This can be changed to your connection name.

Look for references like:

```json
    azureSubscription: 'azure-knowledge-mining-arm-connection'
```

1. Click `Pipelines` from the left menu
2. Click `New Pipeline` button
3. Select `Azure Repos Git`
4. Click Azure Repository that has the pipelines
5. Click `Existing Azure Pipelines YAML file`

### Azure Infrastructure

1. Choose `/azure-pipelines-infra.yml`
2. Click `Continue`
3. Click Variables and create the following

    Click on `Let users override this value when running this pipeline` for each variable.

    - LOCATION (value as: CanadaCentral)
    - RESOURCEGROUP (value as:  knowledge-mining-dev)
    - SPNOBJECTID (value as: `Enterprise Application Object Id` of the Service Principal from above)

4. Click Save
5. Click Run
6. Monitor the job to ensure it is successful.  Check the Azure subscription for the new resource group based on the variable above.

### Azure Search

1. Choose `/azure-pipelines-search.yml`
2. Click `Continue`
3. Click Variables and create the following

    Click on `Let users override this value when running this pipeline` for each variable.

    - KEYVAULT (value as: The name of the Azure Key Vault instance.  You will find this name in the Resource Group.  i.e. `akv-j3toevaceiwp4`)

4. Click Save
5. Click Run
6. Monitor the job to ensure it is successful.  Navigate to the Azure Search instance deployed in the Resource Group to review the configuration.  You will see `Index`, `Indexer`, `Data sources` and `Skillsets` configured.


### Application

1. Choose `/azure-pipelines-app.yml`
2. Click `Continue`
3. Click Variables and create the following

    Click on `Let users override this value when running this pipeline` for each variable.

    - APPSERVICENAME (value as: The name of the Azure App Service instance.  You will find this name in the Resource Group.  i.e. `site-j3toevaceiwp4`)

4. Click Save
5. Click Run
6. Monitor the job to ensure it is successful.  Navigate to the Azure App Service instance deployed in the Resource Group and click Browse.  This will launch the URL of the application.


## Automated Deployments

All 3 pipelines are configured to automatically trigger when changes are made to their respective folders.

All you need to do is push/merge changes into `app`, `arm` and `search-index` folders.  Once complete, their respective pipelines will be automatically triggered.

## Manual deployment

Could be done fully in an Azure Cloud Shell (Bash)

- git clone this repo

- build Infra

  -- Verify Subscription
  ```
  az account set -s "<subscription name>"
  ```
  -- [Optional] Create App Registration and note ObjectID, you could also use your current user Identity
  
  ```
  az ad user list --upn <user email>
  ``` 

  -- Create Resource Group and grant Contributor access to App Registration
 ```
 az group create -l "Canada Central" -n <RG NAME>
  ```
 
  -- Run Bicep Deployment to provision Infrastructure

```
cd ~/knowledge-mining/arm
az deployment group create -g <RG NAME> --template-file env-vnet-integration.bicep --parameters docsContainerName=documents spnObjectId=<objectID-of-you-or-appregistration>
```

- Build and Deploy Custom Email Filtering Skill

```
cd ~/knowledge-mining/skills
chmod +x builddeploy.sh
./builddeploy.sh <RG NAME> <FUNCTION NAME>

```

- build Search Configuration (index, indexer, skillset)
```
cd ~/knowledge-mining/search-index
chmod +x deploy.sh
./deploy.sh ~/knowledge-mining/search-index <STORAGE RESID>  documents <SEARCH ENDPOINT> <SEARCH KEY> <COG SERVICE KEY> <FUNCTION APPNAME> <FUNCTION CODE>
```

Example:
```
./deploy.sh ~/knowledge-mining/search-index /subscriptions/xxxxx/resourceGroups/gackm/providers/Microsoft.Storage/storageAccounts/storageaccount  documents https://search-xxxxx.search.windows.net DDXXXXX b97a864ccc3a4xxxx  function-app-zzzz Axxxxx==
```

Note: parameters could be copied from deployment output and keyvault secrets and Funcion itself


- Build and Deploy Search Application to App Service
```
cd ~/knowledge-mining/app
chmod +x builddeploy.sh
./builddeploy.sh <RG NAME> <APPSVC NAME>

```
