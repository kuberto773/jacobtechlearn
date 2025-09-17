#!/bin/bash

az group create --name rg-shared --location polandcentral

az acr create \
    --resource-group rg-shared \
    --name jacobtechlearnacr \
    --sku Basic \
    --tags env=devl
