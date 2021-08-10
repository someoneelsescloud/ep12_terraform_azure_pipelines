variable "assetname" {
  type        = string
  description = "String to create environment specific values in resources. Acceptable values DEV, TEST, PROD"
}

variable "environment" {
  type        = string
  description = "String to create environment specific values in resources. Acceptable values DEV, TEST, PROD"
}

variable "location" {
  type        = string
  description = "String to specify target region for deployment. Example values eastus or westus"
}