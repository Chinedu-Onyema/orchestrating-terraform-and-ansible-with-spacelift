# -----------------------------------------------------------------------------
# Provider: deploy all resources into the stockholm (eu-north-1) region
# -----------------------------------------------------------------------------
provider "aws" {
  region = "eu-north-1"
}

# -----------------------------------------------------------------------------
# Data source: look up the latest Ubuntu 20.04 (Focal) AMI published by Canonical
# so we never hardcode an AMI ID (IDs differ per region and change over time)
# -----------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true               # use the latest newest AMI from ubuntu

  # Match the Ubuntu 22.04 server image naming pattern (wildcard = any build date)
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  # Use hardware virtual machine (HVM) images, required by modern instance types
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # 64-bit Intel/AMD architecture (matches t3.micro)
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  # Only trust images owned by Canonical (Ubuntu's publisher) to avoid
  # picking up look-alike AMIs from other accounts or community AMIs
  
  owners = ["099720109477"]            # Canonical's AWS account ID
}                                      # this "099720109477" represents Canonical
                                       # and no other publisher

# -----------------------------------------------------------------------------
# Locals: map of instances to create. Each key (instance1 or instance2) 
# becomes the EC2 instance's name on AWS,
# and each value holds that instance's settings. Add or remove entries here
# to scale the fleet up or down.
# -----------------------------------------------------------------------------
locals {
  instances = {
    instance1 = {
      ami           = data.aws_ami.ubuntu.id      # latest Ubuntu 20.04 AMI from above
      instance_type = "t3.micro"                  
    }
    instance2 = {
      ami           = data.aws_ami.ubuntu.id
      instance_type = "t3.micro"
    }
  }
}

# -----------------------------------------------------------------------------
# Key pair: registers your PUBLIC key with AWS so instances launched with it
# accept SSH logins from the matching private key (used by Ansible)
# -----------------------------------------------------------------------------
resource "aws_key_pair" "ssh_key" {
  key_name   = "ansible_key"             # name of the private key pair on AWS and Ansible
  public_key = file(var.public_key)      # reads the public key from the file path in var.public_key 
                                         # in the variables.tf file. we will create a variables file for this
}

# ------------------------------------------------------------------------------
# create a security group for SSH
# this will allow ansible remotely access the instance
# ------------------------------------------------------------------------------
resource "aws_security_group" "ansible_ssh" {
  name        = "ansible-ssh"
  description = "Allow SSH for Ansible"

  ingress {
    description = "SSH from Spacelift workers"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]           # for production environments, replace with Spacelift IP                                         # IPs or your own range
  }                                       

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# -----------------------------------------------------------------------------
# EC2 instances: one instance is created for each entry in local.instances
# EC2 instances: this tells Terraform to create EC2 instances
# using the configurations defined in the locals (specified instances to create)
# -----------------------------------------------------------------------------
resource "aws_instance" "this" {
  for_each      = local.instances                     # Loop over the local.instances map.
                                                      # Terraform creates one EC2 instance per entry
                                                      # as specified Inside the instances block, each.key is the
                                                      # entry name (e.g. "instance1") and each.value holds its settings.

  ami           = each.value.ami                      # AMI (OS image) to boot from, taken from this entry's "ami" value

  instance_type = each.value.instance_type            # Instance size (CPU/RAM), taken from this entry's "instance_type" value

  key_name      = aws_key_pair.ssh_key.key_name       # Name of the AWS key pair attached to the instance, so the matching
                                                      # private key can SSH in (this is how Ansible will connect) to the instances

  associate_public_ip_address = true             # give each instance a public IP so Ansible can reach it over SSH
                                                 # in reality, use private IPs and connect over baston host or just use sessions manager
                                                 # Ansible has an aws_ssm connection plugin, 
                                                 # so it can run over SSM. This is the most common modern approach.
  
  vpc_security_group_ids = [aws_security_group.ansible_ssh.id]          # attach your security group
                                                                        # to your EC2 instance
 
 tags = {
    Name = each.key                            # tag the instance as instance1, instance2, etc.
  }
}




