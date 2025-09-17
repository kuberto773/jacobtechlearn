#!/bin/bash

# ------------------------
# VARIABLES
# ------------------------
RESOURCE_GROUP="rg-svc"
ACR_RESOURCE_GROUP="rg-shared"
LOCATION="canadacentral"
APP_NAME="jacobtechlearn"
PLAN_NAME="asp-jacobtechlearn"
ACR_NAME="jacobtechlearnacr"
IMAGE_NAME="requestloggerapp:latest"
LOG_ANALYTICS_WORKSPACE="law-jacobtechlearn"
APP_INSIGHTS="appi-jacobtechlearn"
UAMI_NAME="umi-jacobtechlearn"

# ------------------------
# 1. Create Resource Group
# ------------------------
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# ------------------------
# 2. Create Log Analytics Workspace
# ------------------------
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_WORKSPACE \
  --location $LOCATION

# ------------------------
# 3. Create Application Insights linked to workspace
# ------------------------
az monitor app-insights component create \
  --app $APP_INSIGHTS \
  --location $LOCATION \
  --resource-group $RESOURCE_GROUP \
  --application-type web \
  --workspace $LOG_ANALYTICS_WORKSPACE

# ------------------------
# 4. Create App Service Plan (Linux)
# ------------------------
az appservice plan create \
  --name $PLAN_NAME \
  --resource-group $RESOURCE_GROUP \
  --sku F1 \
  --is-linux

# ------------------------
# 5. Create User-Assigned Managed Identity
# ------------------------
az identity create \
  --name $UAMI_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

UAMI_ID=$(az identity show --name $UAMI_NAME --resource-group $RESOURCE_GROUP --query id -o tsv)
UAMI_PRINCIPAL_ID=$(az identity show --name $UAMI_NAME --resource-group $RESOURCE_GROUP --query principalId -o tsv)

# ------------------------
# 6. Grant UAMI AcrPull role on ACR
# ------------------------
ACR_ID=$(az acr show --name $ACR_NAME --resource-group $ACR_RESOURCE_GROUP --query id -o tsv)

az role assignment create \
  --assignee $UAMI_PRINCIPAL_ID \
  --scope $ACR_ID \
  --role AcrPull

# ------------------------
# 7. Create Web App with User-Assigned Managed Identity
# ------------------------
az webapp create \
  --resource-group $RESOURCE_GROUP \
  --plan $PLAN_NAME \
  --name $APP_NAME \
  --acr-use-identity \
  --acr-identity $UAMI_ID \
  --assign-identity $UAMI_ID \
  --container-image-name $ACR_NAME.azurecr.io/$IMAGE_NAME \

# ------------------------
# 8. Enable continuous deployment
# ------------------------
az webapp deployment container config \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --enable-cd true

# ------------------------
# 9. Link Application Insights
# ------------------------
APP_INSIGHTS_CONNECTION_STRING=$(az monitor app-insights component show \
  --app $APP_INSIGHTS \
  --resource-group $RESOURCE_GROUP \
  --query connectionString -o tsv)

az webapp config appsettings set \
  --name $APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings "APPLICATIONINSIGHTS_CONNECTION_STRING=$APP_INSIGHTS_CONNECTION_STRING"

echo "✅ Deployment complete!"
echo "App Service: $APP_NAME"
echo "App Insights: $APP_INSIGHTS"
echo "Log Analytics Workspace: $LOG_ANALYTICS_WORKSPACE"
echo "User-Assigned Managed Identity: $UAMI_NAME"
