terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "mel-ciscolabs-com"
    workspaces {
      name = "dev-cpoc-fso-iks-1"
    }
  }
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    # thousandeyes = {
    #   # source = "thousandeyes/thousandeyes"
    #   source = "william20111/thousandeyes"
    #   # source = "cgascoig/cgascoig/thousandeyes"   # this is a custom build of the william20111/thousandeyes provider with a bug fixed (see https://github.com/william20111/terraform-provider-thousandeyes/issues/59)
    # }
  }
}

### Remote State - Import Kube Config ###
data "terraform_remote_state" "iks-1" {
  backend = "remote"

  config = {
    organization = "mel-ciscolabs-com"
    workspaces = {
      name = "iks-cpoc-syd-demo-1"
    }
  }
}

### Decode Kube Config ###
# Assumes kube_config is passed as b64 encoded
locals {
  kube_config = yamldecode(base64decode(data.terraform_remote_state.iks-1.outputs.kube_config))
}

### Providers ###
provider "kubernetes" {
  # alias = "iks-k8s"
  host                   = local.kube_config.clusters[0].cluster.server
  cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
  client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
  client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
}

provider "helm" {
  kubernetes {
    host                   = local.kube_config.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
    client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
    client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
  }
}

# provider "thousandeyes" {
#   token = var.te_token # Passed from Workspace Variable
# }

module "fso" {
  source = "github.com/cisco-apjc-cloud-se/terraform-helm-fso"

  # thousandeyes = {
  #   enabled = true
  #   http_tests = {
  #     fso-demo-app = {
  #       name                    = "fso-demo-app"
  #       interval                = 60
  #       url                     = "http://fso-demo-app.cisco.com"
  #       content_regex           = ".*"
  #       network_measurements    = true # 1
  #       mtu_measurements        = true # 1
  #       bandwidth_measurements  = false # 0
  #       bgp_measurements        = true # 1
  #       use_public_bgp          = true # 1
  #       num_path_traces         = 0
  #       agents                  = [
  #         ## "Adelaide, Australia",
  #         # "Auckland, New Zealand",
  #         # "Brisbane, Australia",
  #         "Melbourne, Australia",
  #         # "Melbourne, Australia (Azure australiasoutheast)",
  #         # "Perth, Australia",
  #         "Sydney, Australia",
  #         # "Wellington, New Zealand"
  #       ]
  #     }
  #   }
  # }

  iwo = {
    enabled                 = true
    namespace               = "iwo"
    cluster_name            = "iks-cpoc-syd-demo-1"
    chart_url               = var.iwo_chart_url  # Passed from Workspace Variable
    server_version          = "8.5"
    collector_image_version = "8.5.1"
    dc_image_version        = "1.0.9-110"
  }

  appd = {
    enabled = true
    kubernetes = {
      namespace = "appd"
    }
    account = {
      name          = var.appd_account_name       # Passed from Workspace Variable
      key           = var.appd_account_key        # Passed from Workspace Variable
      otel_api_key  = var.appd_otel_api_key       # Passed from Workspace Variable
      username      = var.appd_account_username   # Passed from Workspace Variable
      password      = var.appd_account_password   # Passed from Workspace Variable
    }
    install_metrics_server  = true
    install_cluster_agent   = true
    install_machine_agents  = true
    infraviz = {
      enable_container_hostid = true
      enable_dockerviz        = true
      enable_serverviz        = true
      stdout_logging          = true
    }
    netviz = {
      enabled = true
    }
    cluster = {
      montior_namespace_regex = ".*"
    }
    autoinstrument = {
      enabled = true
      namespace_regex = "coolsox"
      default_appname = "coolsox-rw"
      # java = {}
      # dotnetcore = {}
      # nodejs = {}
      # imageinfo = {}
    }
  }
}
