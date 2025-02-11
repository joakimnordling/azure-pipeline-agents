variable address_space {
  default                      = "10.32.0.0/12"
}

variable devops_org {}
variable devops_pat {}

variable linux_agent_count {
  default                      = 2
  type                         = number
}
variable linux_os_offer {
  default                      = "UbuntuServer"
}
variable linux_os_publisher {
  default                      = "Canonical"
}
variable linux_os_sku {
  default                      = "18.04-LTS"
}
variable linux_pipeline_agent_name {
  # Defaults to VM name if empty string
  default                      = "ubuntu1804-agent"
}
variable linux_pipeline_agent_pool {
  default                      = "Default"
}
variable linux_storage_type {
  default                      = "Standard_LRS"
}
variable linux_vm_name_prefix {
  default                      = "ubuntu1804-agent"
}
variable linux_vm_size {
  default                      = "Standard_D2s_v3"
}

variable location {
  default                      = "westeurope"
}

variable resource_suffix {
  description                  = "The suffix to put at the of resource names created"
  default                      = "" # Empty string triggers a random suffix
}

variable run_id {
  description                  = "The ID that identifies the pipeline / workflow that invoked Terraform"
  default                      = ""
}

variable ssh_public_key {
  default                      = "~/.ssh/id_rsa.pub"
}

variable use_scale_set {
  default                      = true
  type                         = bool
}
variable use_self_hosted {
  default                      = false
  type                         = bool
}

variable user_name {
  default                      = "devopsadmin"
}

variable vm_accelerated_networking {
  default                      = false
}

variable windows_agent_count {
  default                      = 2
  type                         = number
}
variable windows_os_offer {
  default                      = "WindowsServer"
}
variable windows_os_publisher {
  default                      = "MicrosoftWindowsServer"
}
variable windows_os_sku {
  default                      = "2019-Datacenter"
}
variable windows_pipeline_agent_name {
  # Defaults to VM name if empty string
  default                      = "windows-agent"
}
variable windows_pipeline_agent_pool {
  default                      = "Default"
}
variable windows_storage_type {
  default                      = "Standard_LRS"
}
variable windows_vm_name_prefix {
  default                      = "win"
}
variable windows_vm_size {
  default                      = "Standard_D4s_v3"
}