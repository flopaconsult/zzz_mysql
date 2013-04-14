#
# Cookbook Name:: mysql
# Recipe:: db_backup
#
# Copyright 2011, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

aws = data_bag_item("aws", "main")

template "/root/.awssecret" do
  source "awssecret.erb"
  owner "root"
  group "root"
  mode "0600"
  variables :aws_secret_access_key => aws['aws_secret_access_key'], :aws_access_key => aws['aws_access_key']
end

bash "install AWS" do
  user "root"
  cwd "/tmp"
  code <<-EOH
    curl https://raw.github.com/timkay/aws/master/aws -o aws
    chmod +x aws
    chown 755 aws
    #perl aws --install  #this is overwriting the ec2-command line tools!
    mv aws /usr/bin/aws
  EOH
  not_if "test -f /usr/bin/aws"
end

bash "install ec2-consistent-snapshot" do
  user "root"
  cwd "/tmp"
  code <<-EOH
    codename=$(lsb_release -cs)
    echo "deb http://ppa.launchpad.net/alestic/ppa/ubuntu $codename main" | tee /etc/apt/sources.list.d/alestic-ppa.list
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys BE09C571
    apt-get update
    apt-get install -y ec2-consistent-snapshot
  EOH
  not_if "test -f /usr/bin/ec2-consistent-snapshot"
end

#TODO: remove _ (this is currently done because of the ec2-tools code for finding .pem's)
cookbook_file "/home/ubuntu/_cert-tu-snapshot.pem" do
  source "cert-tu-snapshot.pem"
  owner "root"
  group "root"
  mode "0700"
end

cookbook_file "/home/ubuntu/_pk-tu-snapshot.pem" do
  source "pk-tu-snapshot.pem"
  owner "root"
  group "root"
  mode "0700"
end

template "/home/ubuntu/create-snapshot.sh" do
  source "create-snapshot.sh.erb"
  owner "root"
  group "root"
  mode "0700"
  variables(
        :db_password => node[:mysql][:server_root_password],
        :aws_secret_access_key => aws['aws_secret_access_key'],
        :aws_access_key => aws['aws_access_key']

        #node['mysql']['server_root_password']
      )
end


template "/etc/cron.d/db-backup" do
  source "db-backup.erb"
  owner "root"
  group "root"
  mode "0622"
end



