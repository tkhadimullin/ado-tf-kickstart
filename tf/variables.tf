#------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
#------------------------------------------------------------------------------

# METADATA / TAGS
variable "environment" {
  type        = string
  default     = ""
  description = "The environment to which this resource group belongs - DEV, PROD."
  validation {
    condition     = contains(["DEV", "PROD"], var.environment)
    error_message = "Environment must be set to 'DEV' or 'PROD'."
  }
}

# GENERAL AZURE RESOURCE MANAGEMENT
variable "subscription_id" {
  type        = string
  description = "The subscription ID for resource management."
}
variable "location" {
  type        = string
  description = "The location of resources - australiaeast, australiasoutheast"
  validation {
    condition     = contains(["australiaeast", "australiasoutheast"], var.location)
    error_message = "Location must be set to 'australiaeast' or 'australiasoutheast'."
  }
}

variable "prefix" {
  type = string
}