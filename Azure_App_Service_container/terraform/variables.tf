variable "env" {
  type    = string
  default = "devl"
}

variable "region" {
  type    = string
  default = "polandcentral"
}

variable "prefix" {
  type    = string
  default = "loggerapp"
}

variable "container_image" {
  type    = string
  default = "requestloggerapp"
}

variable "container_tag" {
  type    = string
  default = "latest"
}

variable "acr_sku" {
  type    = string
  default = "Basic"
}

variable "service_plan" {
  type = object({
    os_type = string
    sku     = string
  })
  default = { os_type = "Linux", sku = "B1" }
}
