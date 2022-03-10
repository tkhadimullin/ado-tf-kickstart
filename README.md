# Bootstrap Azure DevOps with Terraform

## Overview

This repo is intended as a kick-start template for infrastructure as code projects leveraging Azure DevOps and Terraform. Infrastructure definition are located in `/tf` and are intentionally very basic. 
The `/bicep` directory contains basic Terraform state bootstrapping code. It is possible that older agents 

## Prerequisites

The script requires [curl](https://curl.se) and [jq](https://stedolan.github.io/jq) to make the API calls and parse responses.

The pipeline assumes it's running on Microsoft-hosted `ubuntu-latest` agents where all tooling like `terraform` and `jq` [are already installed](https://github.com/actions/virtual-environments/blob/main/images/linux/Ubuntu2004-Readme.md).

# Running the template

Script requires a number of variables to work:

* ADO PAT with sufficient permissions so it can create projects
* Azure subscription details
* AAD tenant Id for ADO to create Service Endpoint
* AAD service principal for ADO to use when running the build/deploy pipeline
* project name being created

The quickest way to start would be to download the `bootstrap.sh` and run it interactively. Environment variables are also accepted (see script for specifics):

```wget https://raw.githubusercontent.com/tkhadimullin/ado-tf-kickstart/master/bootstrap.sh -qO bootstrap.sh && bootstrap.sh```

The script will interactively prompt all required values, create ADO project, import this repository as starting point, register build pipeline, service connection and variables.

From there it should only need running the pipeline via ADO to deploy the infrastructure.