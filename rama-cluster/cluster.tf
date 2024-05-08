###
# variables & configuration
###

## Required vars

variable "region" { type = string }

variable "cluster_name" { type = string } # from rama-cluster.sh
variable "key_name" { type = string }     # from ~/.rama/auth.tfvars

# From rama.tfvars
variable "username" { type = string }
variable "vpc_security_group_ids" { type = list(string) }

variable "rama_source_path" { type = string }
variable "license_source_path" { type = string }
variable "zookeeper_url" { type = string }

variable "conductor_ami_id" { type = string }
variable "supervisor_ami_id" { type = string }
variable "zookeeper_ami_id" { type = string }

variable "zookeeper_instance_type" { type = string }
variable "conductor_instance_type" { type = string }
variable "supervisor_instance_type" { type = string }

variable "supervisor_num_nodes" { type = number }

## Optional vars

variable "zookeeper_num_nodes" {
  type    = number
  default = 1
}

variable "supervisor_volume_size_gb" {
  type    = number
  default = 100
}

variable "private_ssh_key" {
  type    = string
  default = null
}

provider "aws" {
  region      = var.region
  max_retries = 25
  version     = "~> 4.1.0"
}

provider "cloudinit" {
  version = "~> 2.2.0"
}

locals {
  zk_private_ips = aws_instance.zookeeper[*].private_ip

  conductor_private_ip = aws_instance.conductor.private_ip

  home_dir    = "/home/${var.username}"
  systemd_dir = "/etc/systemd/system"

  # networking
  vpc_security_group_ids = var.vpc_security_group_ids
  #vpc_security_group_ids = [module.vpc.default_security_group_id]
  #vpc_id                 = module.vpc.vpc_id
  #subnet_id              = module.vpc.public_subnets[0]
}

###
# VPC
###

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

###
# Create EC2 instances
#
# These resources are defined to have no dependencies on other resouces. This
# way the EC2 instances can be created in parallel, which saves time.
###

resource "aws_instance" "zookeeper" {
  ami           = var.zookeeper_ami_id
  instance_type = var.zookeeper_instance_type
  # subnet_id              = local.subnet_id
  vpc_security_group_ids = local.vpc_security_group_ids
  key_name               = var.key_name
  count                  = var.zookeeper_num_nodes

  tags = {
    Name = "${terraform.workspace}-cluster-zookeeper"
  }

  root_block_device {
    volume_size = 100
  }

  provisioner "file" {
    destination = "${local.home_dir}/zookeeper.service"
    content = templatefile("zookeeper/zookeeper.service", {
      username = var.username
    })
  }

  connection {
    type        = "ssh"
    user        = var.username
    host        = self.private_ip
    private_key = var.private_ssh_key != null ? file(var.private_ssh_key) : null
  }
}

# Conductor

data "cloudinit_config" "conductor_config" {
  part {
    content_type = "text/x-shellscript"
    content = templatefile("setup-disks.sh", {
      username = var.username
    })
  }

  part {
    content_type = "cloud-config"
    content = templatefile("conductor/cloud-config.yaml", {
      username = var.username,
      # rama.yaml
      rama_yaml_contents = templatefile("conductor/rama.yaml", {
        zk_private_ips = local.zk_private_ips
      }),
      # conductor.service
      service_name             = "conductor",
      service_file_destination = "${local.systemd_dir}/conductor.service",
      service_file_contents = templatefile("systemd-service-template.service", {
        description = "Rama Conductor",
        command     = "conductor"
      }),
      # rama.license
      license_file_contents = file("${var.license_source_path}"),
      # Manage rama.zip script
      unpack_rama_contents = templatefile("conductor/unpack-rama.sh", {
        username = var.username
      })
    })
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("conductor/start.sh", {
      username = var.username
    })
  }
}

resource "aws_instance" "conductor" {
  ami           = var.conductor_ami_id
  instance_type = var.conductor_instance_type
  #subnet_id              = local.subnet_id
  vpc_security_group_ids = local.vpc_security_group_ids
  key_name               = var.key_name

  user_data = data.cloudinit_config.conductor_config.rendered

  tags = {
    Name = "${terraform.workspace}-cluster-conductor"
  }

  root_block_device {
    volume_size = 100
  }

  provisioner "remote-exec" {
    # Make sure SSH is up and available on the server before trying to upload rama.zip
    inline = ["ls"]
  }

  provisioner "local-exec" {
    when    = create
    command = "./upload_rama.sh ${var.rama_source_path} ${var.username} ${self.private_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /data/rama",
      "chmod +x unpack-rama.sh",
      "./unpack-rama.sh"
    ]
  }

  connection {
    type        = "ssh"
    user        = var.username
    host        = self.private_ip
    private_key = var.private_ssh_key != null ? file(var.private_ssh_key) : null
  }
}

# Supervisors

data "cloudinit_config" "supervisor_config" {
  part {
    content_type = "text/x-shellscript"
    content = templatefile("setup-disks.sh", {
      username = var.username
    })
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("download_rama.sh", {
      conductor_ip = local.conductor_private_ip
    })
  }

  part {
    content_type = "text/cloud-config"
    filename     = "cloud-config.yaml"
    content = templatefile("cloud-config.yaml", {
      rama_yaml_contents = templatefile("supervisor/rama.yaml", {
        zk_private_ips       = local.zk_private_ips
        conductor_private_ip = aws_instance.conductor.private_ip
      })
      service_file_destination = "${local.systemd_dir}/supervisor.service",
      service_file_contents = templatefile("systemd-service-template.service", {
        description = "Rama Supervisor"
        command     = "supervisor"
      })
      service_name = "supervisor"
      username     = var.username
    })
  }

  part {
    # Supervisor's own IP can't be templated into rama.yaml above, so
    # we need to run a script to look it up from the instance metadata
    content_type = "text/x-shellscript"
    content = templatefile("supervisor/start.sh", {
      username = var.username
    })
  }
}

resource "aws_instance" "supervisor" {
  ami           = var.supervisor_ami_id
  count         = var.supervisor_num_nodes
  instance_type = var.supervisor_instance_type
  #subnet_id              = local.subnet_id
  vpc_security_group_ids = local.vpc_security_group_ids
  key_name               = var.key_name

  user_data = data.cloudinit_config.supervisor_config.rendered

  tags = {
    Name = "${terraform.workspace}-cluster-supervisor"
  }

  root_block_device {
    volume_size = var.supervisor_volume_size_gb
  }

  connection {
    type        = "ssh"
    user        = var.username
    host        = self.private_ip
    private_key = var.private_ssh_key != null ? file(var.private_ssh_key) : null
  }
}

###
# Configure the EC2 instances created above
###

resource "null_resource" "zookeeper" {
  count = var.zookeeper_num_nodes

  connection {
    type        = "ssh"
    user        = var.username
    host        = aws_instance.zookeeper[count.index].private_ip
    private_key = var.private_ssh_key != null ? file(var.private_ssh_key) : null
  }

  triggers = {
    zookeeper_ids = "${join(",", aws_instance.zookeeper.*.id)}"
  }

  provisioner "file" {
    source      = "zookeeper/setup.sh"
    destination = "${local.home_dir}/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.home_dir}/setup.sh",
      "${local.home_dir}/setup.sh ${var.zookeeper_url}"
    ]
  }

  provisioner "file" {
    content = templatefile("zookeeper/zoo.cfg", {
      num_servers    = var.zookeeper_num_nodes,
      zk_private_ips = local.zk_private_ips,
      server_index   = count.index
      username       = var.username
    })
    destination = "${local.home_dir}/zookeeper/conf/zoo.cfg"
  }

  provisioner "file" {
    content = templatefile("zookeeper/myid", {
      zkid = count.index + 1
    })
    destination = "${local.home_dir}/zookeeper/data/myid"
  }

  provisioner "remote-exec" {
    script = "zookeeper/start.sh"
  }
}

###
# Setup local to allow `rama-my-cluster` commands
# TODO find some way to include all ZK ip addresses :(
###
resource "null_resource" "local" {
  # Render to local file on machine
  # https://github.com/hashicorp/terraform/issues/8090#issuecomment-291823613
  provisioner "local-exec" {
    command = format(
      "cat <<\"EOF\" > \"%s\"\n%s\nEOF",
      "/tmp/deployment.yaml",
      templatefile("local.yaml", {
        zk_private_ip        = aws_instance.zookeeper[0].private_ip
        conductor_private_ip = local.conductor_private_ip
      })
    )
  }
}

###
# Output useful info
###
output "zookeeper_ips" {
  value = local.zk_private_ips
}

output "conductor_ip" {
  value = local.conductor_private_ip
}

output "supervisor_ids" {
  value = aws_instance.supervisor.*.private_ip
}

output "conductor_ui" {
  value = "http://${local.conductor_private_ip}:8888"
}

output "ec2_console" {
  value = "https://us-west-2.console.aws.amazon.com/ec2/v2/home?region=us-west-2#Instances:tag:Name=${var.cluster_name}-cluster-supervisor,${var.cluster_name}-cluster-conductor,${var.cluster_name}-cluster-zookeeper;instanceState=running;sort=desc:tag:Name"
}
