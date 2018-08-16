variable "name" {
  default = "binary-authorisation"
  description = "GKE cluster name"
}

variable "zone" {
  default = "asia-southeast1-b"
}

variable "depends_on" {
  default     = []
  type        = "list"
  description = "Hack for expressing module to module dependency"
}