#!/usr/bin/bash

if [[ -z ${ORG} ]];
then
    read -rp "Specify ADO Organisation:" ORG
fi
if [[ -z ${ADO_PAT} ]];
then
    read -rp "Script requires Azure DevOps PAT token to run:" -s ADO_PAT
    echo ""
fi
if [[ -z ${PROJECT_NAME} ]];
then
    read -rp "Specify project name:" PROJECT_NAME
fi
if [[ -z ${TENANT_ID} ]];
then
    read -rp "Specify target Azure AD Tenant id:" TENANT_ID
fi
if [[ -z ${SUBSCRIPTION_ID} ]];
then
    read -rp "Specify target Azure Subscription id:" SUBSCRIPTION_ID
fi
if [[ -z ${SUBSCRIPTION_NAME} ]];
then
    read -rp "Specify target Azure Subscription name:" SUBSCRIPTION_NAME
fi
if [[ -z ${SERVICE_PRINCIPAL_ID} ]];
then
    read -rp "Specify Azure Service Principal id in target tenant:" SERVICE_PRINCIPAL_ID
fi
if [[ -z ${SERVICE_PRINCIPAL_SECRET} ]];
then
    read -rp "Specify target Azure Subscription name:" -s SERVICE_PRINCIPAL_SECRET
    echo ""
fi
if [[ -z ${PROJECT_PREFIX} ]];
then
    read -rp "Specify project prefix for resource identification:" -s PROJECT_PREFIX
fi


# =========== API calls below =============
baseUrl="https://dev.azure.com/$ORG"
SOURCE_REPO_URL="https://github.com/tkhadimullin/ado-tf-kickstart.git"
ENDPOINT_NAME="$SUBSCRIPTION_NAME($SUBSCRIPTION_ID)"

# check or create ADO project
project=$(curl -u :"$ADO_PAT" -sX GET "$baseUrl/_apis/projects?api-version=7.1-preview.4" | jq -r '.value[] | select(.name == "'"$PROJECT_NAME"'")' )

if [[ -n "${project}" ]]; then
    echo "project exists"
else
    basicProcess=$(curl -u :"$ADO_PAT" -sX GET "$baseUrl/_apis/process/processes?api-version=7.1-preview.1"  | jq -r '.value[] | select(.name == "Basic").id' )
    
    createProjectRequest=$(jq -n \
        --arg projectName "$PROJECT_NAME" \
        --arg processId "$basicProcess" \
        '{ "name": $projectName, "description": $projectName, "capabilities": { "versioncontrol": { "sourceControlType": "Git" }, "processTemplate": { "templateTypeId": $processId }}}')
    operation=$(curl -u :"$ADO_PAT" -H 'Content-Type:application/json' -sX POST "$baseUrl/_apis/projects?api-version=7.1-preview.4" -d "$createProjectRequest")
    operationStatus=$(echo "$operation" | jq -r '.status')
    operationId=$(echo "$operation" | jq -r '.id')

    while [[ $operationStatus != "succeeded" ]]; do
        sleep 5        
        operation=$(curl -u :"$ADO_PAT" -sX GET "$baseUrl/_apis/operations/$operationId?api-version=7.1-preview.1")
        operationStatus=$(echo "$operation" | jq -r '.status')
    done
    project=$(curl -u :"$ADO_PAT" -sX GET "$baseUrl/_apis/projects?api-version=7.1-preview.4" | jq -r '.value[] | select(.name == "'"$PROJECT_NAME"'")' )
fi

#check or create Git repo
projectId=$(echo "$project" | jq -r '.id')
gitRepo=$(curl -u :"$ADO_PAT" -sX GET "$baseUrl/$projectId/_apis/git/repositories?api-version=7.1-preview.1" | jq -r '.value[] | select(.name == "'"$PROJECT_NAME"'")')
gitRepoId=$(echo "$gitRepo" | jq -r '.id')
gitRepoUrl=$(echo "$gitRepo" | jq -r '.url')
existingCommits=$(curl -u :"$ADO_PAT" -sX GET "$baseUrl/$projectId/_apis/git/repositories/$gitRepoId/commits?api-version=7.1-preview.1" | jq -r '.count')
if (( existingCommits > 0 )); then
    echo "has commits"
else
    createImportRequest=$(jq -n \
        --arg projectName "$PROJECT_NAME" \
        --arg repoUrl "$SOURCE_REPO_URL" \
        '{
            "repository": {
                "name": $projectName
            },
            "parameters": {
                "gitSource": {
                    "url": $repoUrl
                }
            }
        }')
    curl -u :"$ADO_PAT" -H 'Content-Type:application/json' -sX POST "$baseUrl/$projectId/_apis/git/repositories/$gitRepoId/importRequests?api-version=7.1-preview.1" -d "$createImportRequest" > /dev/null
fi

pipelineSearchResult=$(curl -u :"$ADO_PAT" -sX GET "$baseUrl/$projectId/_apis/build/definitions?api-version=7.1-preview.7&name=default")
pipelineCount=$(echo "$pipelineSearchResult" | jq -r '.count')
if (( pipelineCount > 0 )); then    
    echo "pipeline exists"
else
    createPipelineRequest=$(jq -n \
        --arg projectName "$PROJECT_NAME" \
        --arg projectId "$projectId" \
        --arg gitRepoId "$gitRepoId" \
        --arg gitRepoUrl "$gitRepoUrl" \
        '{
            "project": {
                "id": $projectId,
                "name": $projectName
            },
            "name": "default",
            "repository": {
                "id": $gitRepoId,
                "defaultBranch": "master",
                "url": $gitRepoUrl,
                "type": "tfsgit"
            },
            "process": {
                "type": 2,
                "yamlFilename": "/azure-pipelines.yml",
            },
            "queueStatus": 0,
            "queue": {
                "name": "default",
                "pool": {
                    "isHosted": true,
                    "name": "default"
                }
            }
        }')
    curl -u :"$ADO_PAT" -H 'Content-Type:application/json' -sX POST "$baseUrl/$projectId/_apis/build/definitions?api-version=7.1-preview.7" -d "$createPipelineRequest"  > /dev/null
fi


# service connection
serviceEndpointResult=$(curl -u :"$ADO_PAT" -sX GET "$baseUrl/$projectId/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4")
serviceEndpointCount=$(echo "$serviceEndpointResult" | jq -r '.count')
if (( serviceEndpointCount > 0 )); then    
    echo "service endpoint exists"
else    
    serviceEndpointRequest=$(jq -n \
        --arg endpointName "$ENDPOINT_NAME" \
        --arg subscriptionId "$SUBSCRIPTION_ID" \
        --arg subscriptionName "$SUBSCRIPTION_NAME" \
        --arg projectName "$PROJECT_NAME" \
        --arg projectId "$projectId" \
        --arg tenantId "$TENANT_ID" \
        --arg servicePrincipalId "$SERVICE_PRINCIPAL_ID" \
        --arg servicePrincipalSecret "$SERVICE_PRINCIPAL_SECRET" \
        '{
            "name": $endpointName,
            "type": "AzureRM",
            "url": "https://management.azure.com/",
            "owner": "library",
            "isReady": true,
            "isShared": false,
            "data": {
                "subscriptionId": $subscriptionId,
                "subscriptionName": $subscriptionName,
                "environment": "AzureCloud",
                "scopeLevel": "Subscription",
                "creationMode": "Manual"
            },
            "serviceEndpointProjectReferences": [
                {
                    "projectReference": {
                        "name": $projectName,
                        "id": $projectId
                    },
                    "name": $endpointName
                }
            ],
            "authorization": {
                "scheme": "ServicePrincipal",
                "parameters": {
                    "tenantid": $tenantId,
                    "serviceprincipalid": $servicePrincipalId,
                    "authenticationType": "spnKey",
                    "serviceprincipalkey": $servicePrincipalSecret 
                }
            }
        }')        
    curl -u :"$ADO_PAT" -H 'Content-Type:application/json' -sX POST "$baseUrl/$projectId/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4" -d "$serviceEndpointRequest"  > /dev/null
fi

# Variable Group
variableGroupResult=$(curl -u :"$ADO_PAT" -sX GET "$baseUrl/$projectId/_apis/distributedtask/variablegroups?api-version=7.1-preview.2&groupName=bootstrap-state-variable-grp")
variableGroupCount=$(echo "$variableGroupResult" | jq -r '.count')
if (( variableGroupCount > 0 )); then    
    echo "variable group exists"
else
    createVariableGroupRequest=$(jq -n \
        --arg projectId "$projectId" \
        --arg projectName "$PROJECT_NAME" \
        --arg serviceEndpointName "$ENDPOINT_NAME" \
        --arg subscriptionId "$SUBSCRIPTION_ID" \
        --arg projectPrefix "$PROJECT_PREFIX" \
        '{
            "type": "Vsts",
            "name": "bootstrap-state-variable-grp",
            "variables": {
                "azureServiceConnection": {
                    "isSecret": false,
                    "value": $serviceEndpointName,
                },
                "location": {
                    "isSecret": false,
                    "value": "australiaeast",
                },
                "prefix": {
                    "isSecret": false,
                    "value": $projectPrefix,
                },
                "targetSubscriptionId": {
                    "isSecret": false,
                    "value": $subscriptionId,
                },
            },
            "variableGroupProjectReferences": [
                {
                    "projectReference": {
                        "id": $projectId,
                        "name": $projectName,
                    },
                    "name": "bootstrap-state-variable-grp",
                    "description": "link 1"
                }
            ]

        }')
    curl -u :"$ADO_PAT" -H 'Content-Type:application/json' -sX POST "$baseUrl/$projectId/_apis/distributedtask/variablegroups?api-version=7.1-preview.2" -d "$createVariableGroupRequest"  > /dev/null
fi

# Environments
environmentsResult=$(curl -u :"$ADO_PAT" -sX GET "$baseUrl/$projectId/_apis/distributedtask/environments?api-version=7.1-preview.1")
environmentsCount=$(echo "$environmentsResult" | jq -r '.count')
if (( environmentsCount > 0 )); then    
    echo "environments exist"
else
    devEnv=$(jq -n \
    '{
        "name": "dev",
        "description": "dev environment"
    }')
    curl -u :"$ADO_PAT" -H 'Content-Type:application/json' -sX POST "$baseUrl/$projectId/_apis/distributedtask/environments?api-version=7.1-preview.1" -d "$devEnv"  > /dev/null
    prodEnv=$(jq -n \
    '{
        "name": "prod",
        "description": "prod environment"
    }')
    curl -u :"$ADO_PAT" -H 'Content-Type:application/json' -sX POST "$baseUrl/$projectId/_apis/distributedtask/environments?api-version=7.1-preview.1" -d "$prodEnv" > /dev/null
fi