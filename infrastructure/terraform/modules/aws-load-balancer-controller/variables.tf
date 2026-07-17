variable "name_prefix" {
  description = "Name prefix for AWS Load Balancer Controller resources."
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for the controller service account."
  type        = string
  default     = "kube-system"
}

variable "kubernetes_service_account" {
  description = "Kubernetes service account used by AWS Load Balancer Controller."
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "tags" {
  description = "Tags applied to AWS resources."
  type        = map(string)
  default     = {}
}
