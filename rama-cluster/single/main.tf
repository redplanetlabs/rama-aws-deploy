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

variable "rama_source_path" {
  type = string
  validation {
    condition     = fileexists(var.rama_source_path)
    error_message = "The rama_source_path file does not exist: ${var.rama_source_path}"
  }
}
variable "license_source_path" {
  type    = string
  default = ""
  validation {
    condition     = var.license_source_path == "" || fileexists(var.license_source_path)
    error_message = "The license_source_path file does not exist: ${var.license_source_path}"
  }
}
variable "zookeeper_url" { type = string }

variable "ami_id" {
  type    = string
  default = ""
  description = "AMI ID to use. If empty, uses latest Amazon Linux 2023 ARM64 from SSM Parameter Store"
}

variable "instance_type" { type = string }
variable "instance_profile" {
  type    = string
  default = null
}

variable "volume_size_gb" {
  type    = number
  default = 100
}

variable "use_private_ip" {
  type    = bool
  default = false
}

variable "private_ssh_key" {
  type    = string
  default = null
  validation {
    condition     = var.private_ssh_key == null || fileexists(var.private_ssh_key)
    error_message = "The private_ssh_key file does not exist: ${var.private_ssh_key}"
  }
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
  home_dir = "/home/${var.username}"
  systemd_dir = "/etc/systemd/system"
  vpc_security_group_ids = var.vpc_security_group_ids
  # Use provided ami_id if set, otherwise fetch latest AL2023 ARM64 from SSM
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.al2023_ami.value
}

###
# VPC
###

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

###
# Latest Amazon Linux 2023 ARM64 AMI
###

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

###
# Create EC2 instance
###

resource "aws_instance" "rama" {
  ami           = local.ami_id
  instance_type = var.instance_type
  # subnet_id              = local.subnet_id
  vpc_security_group_ids = local.vpc_security_group_ids
  iam_instance_profile   = var.instance_profile
  key_name               = var.key_name

  user_data = data.cloudinit_config.rama_config.rendered

  tags = {
    Name = "${terraform.workspace}-rama"
  }

  root_block_device {
    volume_size = var.volume_size_gb
  }

  # Zookeeper setup
  provisioner "file" {
    destination = "${local.home_dir}/zookeeper.service"
    content = templatefile("../common/zookeeper/zookeeper.service", {
      username = var.username
    })
  }

  # Conductor setup
  provisioner "remote-exec" {
	# Wait for disk provisioning to complete
	inline = [
	  "echo 'Waiting for disks to complete...'",
	  "while [ ! -f /tmp/disks_complete.signal ]; do sleep 1; done",
	  "echo 'Disks ready, continuing...'"
	]
  }

  provisioner "file" {
	source = "../common/conductor/unpack-rama.sh"
	destination = "/home/${var.username}/unpack-rama.sh"
  }

  provisioner "local-exec" {
	when = create
	command = "scp -o 'StrictHostKeyChecking no' ${var.rama_source_path} ${var.username}@${var.use_private_ip ? self.private_ip : self.public_ip}:/home/${var.username}/rama.zip"
  }

  provisioner "remote-exec" {
	inline = [
	  "sudo mv /home/${var.username}/unpack-rama.sh /data/rama/",
	  "sudo mv /home/${var.username}/rama.zip /data/rama/",
	  "sudo chown ${var.username}:${var.username} /data/rama/unpack-rama.sh /data/rama/rama.zip",
	  "cd /data/rama",
	  "chmod +x unpack-rama.sh",
	  "./unpack-rama.sh"
	]
  }

  connection {
    type        = "ssh"
    user        = var.username
    host        = var.use_private_ip ? self.private_ip : self.public_ip
    private_key = var.private_ssh_key != null ? file(var.private_ssh_key) : null
  }
}

data "cloudinit_config" "rama_config" {
  part {
	content_type = "text/x-shellscript"
	content = templatefile("../common/setup-disks.sh", {
	  username = var.username
	})
  }

  part {
	# Conductor setup
	content_type = "text/cloud-config"
	content = templatefile("./cloud-config.yaml", {
	  username = var.username,

	  # conductor.service
	  conductor_service_name = "conductor",
	  conductor_service_file_destination = "${local.systemd_dir}/conductor.service",
	  conductor_service_file_contents = templatefile("../common/systemd-service-template.service", {
		description = "Rama Conductor",
		command     = "conductor"
	  })
	  # rama.license
	  license_file_contents = var.license_source_path != "" ? file(var.license_source_path) : "",
	  # Manage rama.zip script
	  unpack_rama_contents = templatefile("../common/conductor/unpack-rama.sh", {
		username = var.username,
	  })

	  supervisor_service_file_destination = "${local.systemd_dir}/supervisor.service",
	  supervisor_service_file_contents = templatefile("../common/systemd-service-template.service", {
		description = "Rama Supervisor"
		command     = "supervisor"
	  })
	  service_name = "supervisor"
	})
  }
}

resource "null_resource" "rama" {
  connection {
	type        = "ssh"
	user        = var.username
	host        = var.use_private_ip ? aws_instance.rama.private_ip : aws_instance.rama.public_ip
	private_key = var.private_ssh_key != null ? file(var.private_ssh_key) : null
  }

  triggers = {
	zookeeper_id = aws_instance.rama.id
  }

  provisioner "file" {
	source = "../common/zookeeper/setup.sh"
	destination = "${local.home_dir}/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "cd ${local.home_dir}",
      "chmod +x setup.sh",
      "./setup.sh ${var.zookeeper_url}"
    ]
  }

  provisioner "file" {
	content = templatefile("../common/zookeeper/zoo.cfg", {
	  num_servers    = 1,
	  zk_private_ips = [aws_instance.rama.private_ip],
	  server_index   = 0
	  username       = var.username
	})
	destination = "${local.home_dir}/zookeeper/conf/zoo.cfg"
  }

  provisioner "file" {
	content = templatefile("../common/zookeeper/myid", {
	  zkid = 1
	})
	destination = "${local.home_dir}/zookeeper/data/myid"
  }

  provisioner "file" {
	content = templatefile("./rama.yaml", {
	  zk_private_ip = aws_instance.rama.private_ip
	  conductor_private_ip = aws_instance.rama.private_ip
	  supervisor_private_ip = aws_instance.rama.private_ip
	})
	destination = "/tmp/rama.yaml"
  }

  provisioner "file" {
	source = "./start.sh"
	destination = "${local.home_dir}/start.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "cd ${local.home_dir}",
      "chmod +x start.sh",
      "./start.sh"
    ]
  }
}

###
# Setup local to allow `rama-my-cluster` commands
###
resource "null_resource" "local" {
  depends_on = [null_resource.rama]

  triggers = {
    instance_id = aws_instance.rama.id
  }

  # Render to local file on machine
  # https://github.com/hashicorp/terraform/issues/8090#issuecomment-291823613
  provisioner "local-exec" {
    command = format(
      "cat <<\"EOF\" > \"%s\"\n%s\nEOF",
      "/tmp/deployment.yaml",
      templatefile("../common/local.yaml", {
        zk_public_ip         = aws_instance.rama.public_ip
        zk_private_ip        = aws_instance.rama.private_ip
        conductor_public_ip  = aws_instance.rama.public_ip
        conductor_private_ip = aws_instance.rama.private_ip
      })
      )
  }
}

###
# Output useful info
###
output "rama_ip" {
  value = var.use_private_ip ? aws_instance.rama.private_ip : aws_instance.rama.public_ip
}

output "conductor_ui" {
  value = "http://${var.use_private_ip ? aws_instance.rama.private_ip : aws_instance.rama.public_ip}:8888"
}

output "ec2_console" {
  value = "https://us-west-2.console.aws.amazon.com/ec2/v2/home?region=us-west-2#Instances:tag:Name=${var.cluster_name}-cluster-supervisor,${var.cluster_name}-cluster-conductor,${var.cluster_name}-cluster-zookeeper;instanceState=running;sort=desc:tag:Name"
}
