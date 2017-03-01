# Cloudify Manager v3.4 - Offline (AWS)

## Getting Started

### Before you begin...

* Read [Working Offline with Cloudify 3.4](http://getcloudify.org/2017/02/15/working-offline-cloudify.html)
* Read that again... We're not joking.


### General information

Bootstrapping, offline or online, generally requires two servers / instances / VMs. One will act
as the Cloudify Manager (the target of a bootstrap operation) and one will act as the
Cloudify CLI (the source of a bootstrap operation). The CLI can be a separate server or it can
be your desktop / laptop, but the Manager should be a separate system (even if that just means
it's a local VM).

This guide assumes you're using your desktop as a CLI and your goal is to have a
new Cloudify Manager bootstrapped offline (without having public network access) in
Amazon AWS. These instructions can easily be applied to other clouds or virtual
environments as the requirements of the Manager server are minimal.


## Prepare the Cloudify Manager (bootstrap target)

### Create an AWS Security Group

In AWS EC2, create a new Security Group called `cloudify-offline-sg` with the following rules:
```
Inbound:
	(delete any existing / default rules)
	Allow port TCP/22 anywhere
    Allow port TCP/80 anywhere

Outbound:
	(delete any existing / default rules)
	Allow port TCP/22 anywhere
```

This will create a Security Group that restricts all outbound traffic to SSH (effectively
cutting it off from downloading any files) and only allowing external access to the
system via SSH (used for bootstrapping) and HTTP (used to access the web UI when complete).

### Create an AWS EC2 Instance

Create a new EC2 instance (which will be your Manager eventually) using a CentOS 7
AMI (such as [this one](https://aws.amazon.com/marketplace/pp/B00O7WM7QW)).

Make sure it has a public IP and it should have 4GB+ of memory and 10GB+ of storage. Use
the Security Group from the last section for this instance. If you haven't already, you'll
need to create (or reuse) a Key Pair for the instance for SSH access.

### Download the Manager Resources package

The only prep work we need to do on this instance is to download a package of
all of the Cloudify Manager resources and place it on the instance. This part is
very specific, so follow along exactly.

On your desktop, download the [Cloudify Manager Resources Package](http://repository.cloudifysource.org/org/cloudify3/3.4.2/sp-RELEASE/cloudify-manager-resources_3.4.2-sp-b420.tar.gz). Since the Manager instance doesn't have outbound HTTP access, we will need to download
the package locally, then push it to the Manager via SCP. Alternatively, you could allow port TCP/80 on
the Manager Security Group for this one step and download it to the Manager directly and then
remove that rule when finished.

Now let's push the package to the Manager and get it in the right spot for bootstrapping later.

```bash
# Download the Manager Resources package
curl -L -o cloudify-manager-resources.tar.gz \
	http://repository.cloudifysource.org/org/cloudify3/3.4.2/sp-RELEASE/cloudify-manager-resources_3.4.2-sp-b420.tar.gz
# Upload the package to the Manager via SCP and put it in /tmp/
scp -i [PATH-TO-MANAGER-PRIVATE-KEY] \
	cloudify-manager-resources.tar.gz \
    centos@[YOUR-MANAGER-PUBLIC-IP]:/tmp/
# Move the package to the right place on the Manager
ssh -i [PATH-TO-MANAGER-PRIVATE-KEY] centos@[YOUR-MANAGER-PUBLIC-IP] -t \
	"sudo mkdir -p /opt/cloudify/sources;" \
    "sudo mv /tmp/cloudify-manager-resources.tar.gz /opt/cloudify/sources/;"
```

However you go about it, the goal is to get the Manager Resources package placed in
`/opt/cloudify/sources/` folder.


## Prepare the Cloudify CLI (bootstrap source)

### Creating a working directory

Before starting anything with the CLI, get a working directory created. It can be something
like `~/cloudify`, but make sure it's empty and ready to be worked in. Enter this directory
when running the following steps to keep things tidy.

Within your working directory, create a subdirectory called `offline` also.

### Get the Cloudify Manager blueprints

Go [here](https://github.com/cloudify-cosmo/cloudify-manager-blueprints/tree/3.4.2) to get the
version 3.4.2 of the manager blueprints. You can either use GIT or plain HTTP download to get
the blueprints.

```bash
# Using GIT
git clone https://github.com/cloudify-cosmo/cloudify-manager-blueprints.git
cd cloudify-manager-blueprints
git checkout tags/3.4.2

# Using cURL
curl -L -o cloudify-manager-blueprints.zip \
	https://github.com/cloudify-cosmo/cloudify-manager-blueprints/archive/3.4.2.zip
unzip cloudify-manager-blueprints.zip
rm cloudify-manager-blueprints.zip
cd cloudify-manager-blueprints
```

You should now have two directories in your working directory - `offline` (currently empty) and `cloudify-manager-blueprints`.

Now, in `cloudify-manager-blueprints/`, copy `simple-manager-blueprint.yaml` to `offline-blueprint.yaml` and `simple-manager-blueprint-inputs.yaml` to `offline-inputs.yaml`.

### Set the blueprint inputs

Open `cloudify-manager-blueprints/offline-inputs.yaml` file for editing.

Find, uncomment, and update the following lines:
```yaml
public_ip: [YOUR-MANAGER-PUBLIC-IP]
private_ip: "127.0.0.1"
ssh_user: "centos"
ssh_key_filename: [PATH-TO-MANAGER-PRIVATE-KEY]
manager_resources_package: "file:///opt/cloudify/sources/cloudify-manager-resources.tar.gz"
ignore_bootstrap_validations: true
management_worker_log_level: "debug"
```

### Create, and activate, a VirtualEnv

From your working directory, execute `virtualenv venv`. This will create a new
Python virtual environment in the venv/ folder.

To activate the virtualenv, execute `source venv/Scripts/activate` (on Windows) or
`source /venv/bin/activate` (on \*nix).

### Install Cloudify CLI

Once you've activated your virtualenv, installing Cloudify CLI is a breeze. Simply
execute `pip install cloudify==3.4.1` and away it goes.

Once complete, you should have a new application installed and you can test it by
executing `cfy --version` with an output similar to this:
```bash
$ cfy --version
Cloudify CLI 3.4.1
```

### Initialize the CLI environment

Before bootstrapping can begin, we need a working environment for the CLI to use. From within
your working directory, execute `cfy init`.

### Download plugins and types

The manager blueprint only contains two different imports. One for the standard Cloudify
types and one for the Fabric (SSH) plugin. Since we're performing an offline install, the
Manager won't be able to actually get those needed files (since they're external references).

So, we will need to download those files (called specs) and store them somewhere locally. Then
when the bootstrap process starts, instead of going out to the internet to get these files, it will
use our local copies instead.

Enter your working directory. Do you remember that `offline/` folder we created long ago? Now it's time to use it. Run the following:

```bash
# Create a root for all getcloudify.org plugins
mkdir -p offline/imports/cloudify/
# Import the standard Cloudify types
curl -L -O http://www.getcloudify.org/spec/cloudify/3.4.2/types.yaml
mkdir -p offline/imports/cloudify/spec/cloudify/3.4.2/
mv types.yaml offline/imports/cloudify/spec/cloudify/3.4.2/
# Import the Fabric plugin types
curl -L -O http://www.getcloudify.org/spec/fabric-plugin/1.4.1/plugin.yaml
mkdir -p offline/imports/cloudify/spec/fabric-plugin/1.4.1/
mv plugin.yaml offline/imports/cloudify/spec/fabric-plugin/1.4.1/
```

Now we need to install (in our virtualenv) the required plugins (only Fabric, in this case). 

```bash
pip install https://github.com/cloudify-cosmo/cloudify-fabric-plugin/archive/1.4.1.zip
```

### Extend the Import Resolver

Now that you have a working environment, you should have a new `.cloudify/` folder in your
working directory. Open `.cloudify/config.yaml` in your editor of choice.

Append the following to the end of the file:
```yaml
import_resolver:
  parameters:
    rules:
    - "http://www.getcloudify.org": "file://[PATH-TO-WORKING-DIRECTORY]/offline/imports/cloudify"
```

### Squash a bug

Open `cloudify-manager-blueprints/components/utils.py` for editing. Find the function
`_download_source_resource` around line 990.

Find the following line of code:
```python
is_url = source.startswith(('http', 'https', 'ftp'))
```

... and replace it with this line of code:
```python
is_url = source.startswith(('http', 'https', 'ftp', 'file'))
```


## Bootstrap!

Finally, the moment has come.

Execute the following from your working directory:
```bash
cfy bootstrap \
	-p ./cloudify-manager-blueprints/offline-blueprint.yaml \
	-i ./cloudify-manager-blueprints/offline-inputs.yaml \
    --debug
```
