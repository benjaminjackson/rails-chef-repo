Overview
========

This project aims to be everything you need to set up multiple servers with littlechef. If anything here doesn't work, file and issue and we'll fix it.

All terminal commands below should be run locally from the `kitchen` directory unless otherwise noted.

## Open Port 80 if Necessary

If you're setting up your server on Amazon EC2 or another host that blocks port 80 by default, you'll need to set up your server's security group with access to port 80 or you won't be able to access your rails site once everything is set up. On EC2:

1. From the instances list in the EC2 Management Console, scroll over to "Security Groups" column and click the group for your server.
2. Click "Actions > Edit inbound rules"
3. Add a new rule with type "HTTP" and save the rule set.

## Dependencies

### Installing Littlechef

	$ curl -L https://www.opscode.com/chef/install.sh | sudo bash
	$ gem install librarian-chef knife-solo knife-solo_data_bag
	$ pip install littlechef

Choose a chef deployment password and add it to config.cfg

### Install ruby dependencies:

```
bundle install
```

## Set up SSH and create littlechef.cfg 

Copy over `kitchen/littlechef.cfg.template` to `kitchen/littlechef.cfg` and update the username to match whatever you're using to log in over SSH.

The template uses an SSH config file at `~/.ssh/config`: a typical one looks like this:

    Host host.name.yourapp.com  
        User chef  
        IdentityFile ~/Downloads/mykey.pem  

## Set up Encrypted Data Bags

Data bags are the place to keep things like user credentials and passwords.
They can be encrypted and stored in git.

### Generate a secret

```
openssl rand -base64 512 | tr -d '\r\n' > config/encrypted_data_bag_secret
```

**Do not lose this secret file!** It will be ignored by git, and without it you won't be able to connect to the server.

### System user passwords

In order to set user passwords (**BUT NOT DATABASE PASSWORDS**), chef uses ruby-shadow with the shadow password hash. This is stored in the user's data bag rather than the plaintext password. For convenience we store the password in a separate
unused attribute. The databag is encrypted and can thus be checked into git.

Password hashes are created with:

`openssl passwd -1 "theplaintextpassword"`

To create the encrypted data bag databags/users/app.json do

`knife solo data bag create users app --secret-file config/encrypted_data_bag_secret`

To edit the bag after creation:

`knife solo data bag create users app --secret-file config/encrypted_data_bag_secret`

Create data bags for server users:

    knife solo data bag create users app --secret-file config/encrypted_data_bag_secret 
    knife solo data bag create users deploy --secret-file config/encrypted_data_bag_secret 

Create data bag for mysql root users:

    knife solo data bag create mysql_root_users/mysql --secret-file config/encrypted_data_bag_secret 

Create data bag for all databases you'll be using on the node (replace `database_name` with each database's name):

    knife solo data bag create databases/database_name --secret-file config/encrypted_data_bag_secret 

### Run pre-chef script

This script adds the chef user with sudo privileges and installs ruby 1.9.3 and some chef-related gems. Some recipes use ruby 1.9 syntax and chef compiles them all before running any recipe (e.g. an rbenv recipe).

**On the server:**
	
```
$ wget https://gist.github.com/wam/89ea3c015efd8c0329a5/raw/01c9b6389ee12f11b860ea971d8e5d0bf2f38741/pre-chef.sh  
$ bash pre-chef.sh
```

### Install chef on the node

Note: All `fix` commands must be executed from the kitchen directory.

At this point, the kitchen/nodes directory should *not* contains a json file for the node we're setting up. It will be created automatically by the next command.

```
$ bundle exec fix node:MYNODE deploy_chef:method=omnibus,version=11.14
```

Now there will be a basic node config file in nodes/host.name.yourapp.com.json. Copy `nodes/sample.json.template` into it and change the username `yournamehere` to the username you created a data bag for above.

### Run the post-chef script

At this point, for some crazy reason, Chef *may* have linked the node's rubygems to 1.8.
So we need to run another script on the node to check that and set it back to 1.9.x if so.

**On the server:**
	
```
$ wget https://gist.github.com/wam/89ea3c015efd8c0329a5/raw/3b54534c4ec01f4c31cbe147b1daa4a37c5a8e5d/post-chef.sh  
$ bash pre-chef.sh
```

### Configure the node

Augment/update the node's json file with a run list and attributes. There is an example in examples/node.json.template showing a rails app setup. At the very least, the basic_server role should be included in the
run list.

	$ bundle exec fix node:host.name.yourapp.com

Copy private keys over to app and admin users:

	ssh-copy-id app@host.name.yourapp.com
	ssh-copy-id admin@host.name.yourapp.com

## Lock down root SSH

    pico /etc/ssh/sshd_config

Find this section in the file, containing the line with “PermitRootLogin” in it, and change to 'no'.

    #LoginGraceTime 2m
    #PermitRootLogin no
    #StrictModes yes
    #MaxAuthTries 6

Then restart ssh:

    service ssh restart
