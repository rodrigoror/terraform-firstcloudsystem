variable "mysql_admin_password" {
  description = "Senha do administrador do MySQL"
  type        = string
  sensitive   = true
}
variable "subscription_id" {
  description = "subscription_id "
  type        = string
  sensitive   = false
}
variable "client_id" {
  description = "client_id       "
  type        = string
  sensitive   = true
}
variable "client_secret" {
  description = "client_secret   "
  type        = string
  sensitive   = true
}
variable "tenant_id" {
  description = "tenant_id"
  type        = string
  sensitive   = true
}
