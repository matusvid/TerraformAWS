terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.74.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}


module "application" {
    source = "./modules/application"
}

module "bastion" {
    source = "./modules/bastion"
}

module "network" {
    source = "./modules/network"
}

module "security" {
    source = "./modules/security"
}

module "storage" {
    source = "./modules/storage"
}