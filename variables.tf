variable "credential" {
  default     = "account.json"
  description = "Contents of a file that contains your service account private key in JSON format."
}

variable "project" {
  default     = "binary-authorisation"
  description = "The ID of the project to apply any resources to."
}

variable "zone" {
  default = "asia-southeast1-b"
}

variable "gcs_location" {
  default = "Asia"
}

variable "name" {
  default = "binary-authorisation"
  description = "GKE cluster name"
}