- [Prerequisites](#prerequisites)
- [Deploying](#deploying)
  - [Deploying a Rama Cluster and Modules](#deploying-a-rama-cluster-and-modules)
- [Cluster Configuration and Debugging](#cluster-configuration-and-debugging)
  - [AMI requirements](#ami-requirements)
  - [systemd and journalctl](#systemd-and-journalctl)
  - [file system layout](#file-system-layout)
- [rama.tfvars variables](#ramatfvars-variables)
  - [username](#username)
  - [vpc\_security\_group\_ids](#vpc_security_group_ids)
  - [rama\_source\_path](#rama_source_path)
  - [license\_source\_path](#license_source_path)
  - [zookeeper\_url](#zookeeper_url)
  - [conductor\_ami\_id](#conductor_ami_id)
  - [supervisor\_ami\_id](#supervisor_ami_id)
  - [zookeeper\_ami\_id](#zookeeper_ami_id)
  - [conductor\_instance\_type](#conductor_instance_type)
  - [supervisor\_instance\_type](#supervisor_instance_type)
  - [zookeeper\_instance\_type](#zookeeper_instance_type)
  - [supervisor\_num\_nodes](#supervisor_num_nodes)
  - [zookeeper\_num\_nodes](#zookeeper_num_nodes)
  - [supervisor\_volume\_size\_gb](#supervisor_volume_size_gb)
  - [use\_private\_ip](#use_private_ip)
  - [private\_ssh\_key](#private_ssh_key)

## Prerequisites

Terraform must be installed.

If you haven't already, create a new EC2 key pair in your AWS Console.
It should automatically download a new `.pem` file. Add the downloaded `.pem`
file to your your private key identities with `ssh-add path/to/file.pem`.

Create a file `~/.rama/auth.tfvars` with the following content:

```
key_name = <name of the key you have configured as a key pair for EC2>
```

`~/.rama` must be added to your PATH.

For AWS authentication, we recommend setting up [aws-vault](https://github.com/99designs/aws-vault).

You can download a Rama release [from our website](https://redplanetlabs.com/download).

## Deploying

`rama-aws-deploy` can be used to create either multi-node or single-node Rama deployments.

### Deploying a multi-node Rama cluster

1. Make sure you have your zip file of Rama and license downloaded.
2. Create `rama.tfvars` at the root of your project to set Terraform variables. These govern e.g. the number of supervisors to deploy. See `rama.tfvars.multi.example`. There are several variables that are required to set.
3. Run `bin/rama-cluster.sh deploy <cluster-name> [opt-args]`.
   `opt-args` are passed to `terraform apply`.
   For example, if you wanted to just deploy zookeeper servers, you would run
   `bin/rama-cluster.sh deploy my-cluster -target=aws_instance.zookeeper`.

### Deploying a single-node Rama cluster

This option deploys Zookeeper, Conductor, and one supervisor onto the same node.

1. Make sure you have your zip file of Rama and license downloaded.
2. Create `rama.tfvars` at the root of your project to set Terraform variables.  See `rama.tfvars.single.example`. There are several variables that are required to set.
3. Run `bin/rama-cluster.sh deploy --singleNode <cluster-name>`.


### Deploying modules

Documentation on how to deploy modules is [on this page](https://redplanetlabs.com/docs/~/operating-rama.html#_launching_modules). `rama-aws-deploy` sets up a symlink in `~/.rama` to a `rama` script pointing to the cluster with the name `rama-<cluster-name>`. Here's an example of deploying self-monitoring for a cluster named "staging":

```
rama-staging deploy \
  --action launch \
  --systemModule monitoring \
  --tasks 8 \
  --threads 2 \
  --workers 2
```


### Destroying a cluster

To destroy a cluster run `bin/rama-cluster.sh destroy <cluster-name>` or `bin/rama-cluster.sh --singleNode destroy <cluster-name>` depending on whether it's a multi-node or single node cluster.

## Cluster Configuration and Debugging

### AMI requirements

Zookeeper and Rama require Java to be present on the system to run.
Rama supports LTS versions of Java - 8, 11, 17 and 21. One of these needs to
be installed on the AMI.

`unzip` and `curl` must also be present on the AMI.

### systemd and journalctl

All deployed processes (zookeeper, conductor rama, supervisor rama) are managed
using systemd. systemd is used to start the processes and restart them if they
exit. Some useful snippets include (substitute `conductor` or `supervisor` for
`zookeeper`):

``` sh
sudo systemctl status zookeeper.service # check if service is running
sudo systemctl start zookeeper.service
sudo systemctl stop zookeeper.service
```

systemd uses journald for logging. Our processes configure their own logging,
but logs related to starting and stopping will be captured by journald. To read
logs:

``` sh
journalctl -u zookeeper.service    # view all logs
journalctl -u zookeeper.service -f # follow logs
```

An application's systemd config file is located at

``` sh
/etc/systemd/system/zookeeper.service
```

### file system layout

Each cluster node has one main application process; zookeeper nodes run
zookeeper, conductor nodes run a rama conductor, supervisor nodes run a rama
supervisor.

The relevant directories to look at are the `$HOME` directory, as well as
`/data/rama`.

## rama.tfvars variables

### region
- type: `string`
- required: `true`

The AWS region to deploy the cluster to.

### username
- type: `string`
- required: `true`

The login username to use for the nodes. Needed to know how to SSH into them and know where the
home directory is located.

### vpc_security_group_ids
- type: `list(string)`
- required: `true`

The security groups that the nodes are members of.

### rama_source_path
- type: `string`
- required: `true`

An absolute path pointing to the location on the local disk of your `rama.zip`.

### license_source_path
- type: `string`
- required: `false`

An absolute path pointing to the location on the local disk of your Rama license file.

### zookeeper_url
- type: `string`
- required: `true`

The URL to download a zookeeper tar ball from to install on the zookeeper node(s).

### conductor_ami_id
- type: `string`
- required: `true`

The AMI ID that the conductor node should use.

### supervisor_ami_id
- type: `string`
- required: `true`

The AMI ID that the supervisor node(s) should use.

### zookeeper_ami_id
- type: `string`
- required: `true`

The AMI ID that the zookeeper node(s) should use.

### conductor_instance_type
- type: `string`
- required: `true`

The AWS instance type that the conductor node should use.

Ex. m6g.medium

### supervisor_instance_type
- type: `string`
- required: `true`

The AWS instance type that the supervisor node(s) should use.

### zookeeper_instance_type
- type: `string`
- required: `true`

The AWS instance type that the zookeeper node(s) should use.

### supervisor_num_nodes
- type: `number`
- required: `true`

The number of supervisor nodes you want to use.

### zookeeper_num_nodes
- type: `number`
- required: `false`
- default: `1`

The number of zookeeper nodes you want to use.

Note: Zookpeeer recommends setting this to an odd number

### supervisor_volume_size_gb
- type: `number`
- required: `false`
- default: `100`

The size of the supervisors' disks on the nodes.

### use_private_ip
- type: `bool`
- required: `false`
- default: `false`

Whether to use the global public IDs, or private internal IPs.

Ex. if your security group is configured to only allow connection through a VPN, you should set
this to true so that you're not coming from outside the network.

### private_ssh_key
- type: `string`
- required: `false`
- default: `null`
