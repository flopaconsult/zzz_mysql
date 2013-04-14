#
# Cookbook Name:: mysql
# Recipe:: install_db_via_ebs
#
# Copyright 2011, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

#copy /home/user/ec2/florian
cookbook_file "/home/ubuntu/florian" do
  source "florian" 
  owner "ubuntu"
  group "ubuntu"
  mode "0700"
end

#cookbook_file "/home/ubuntu/.ssh/config" do
#  source "ssh_config" 
#  owner "ubuntu"
#  group "ubuntu"
#  mode "0700"
#end

execute "resize root EBS volume" do
  command "resize2fs /dev/sda1"
  action :run
end

aws_ebs_volume "mount magento backup database snapshot" do
  provider "aws_ebs_volume"
  aws_access_key node[:runa][:aws_access_key]
  aws_secret_access_key node[:runa][:aws_secret_access_key]
  snapshot_id node[:runa][:snapshot_id]
  availability_zone node[:ec2][:placement_availability_zone]
  device node[:runa][:device]
  action [:create, :attach]
end

ruby_block "wait for EBS volume to get attached"  do
  block do
    sleep(60)
  end
  action :create
  not_if "cat /proc/mounts | grep /db-backup" # only wait the first time
end

directory "/db-backup" do
  action :create
  recursive true
  mode 0755
  owner "root"
  group "root"
end

mount "/db-backup" do
  device node[:runa][:device]
  options "rw noatime"
  fstype "ext3"
  action [ :enable, :mount ]
  # Do not execute if its already mounted
  not_if "cat /proc/mounts | grep /db-backup"
end

execute "unpack_database_file" do
  command "gunzip clean_db.sql.gz"
  action :nothing
  cwd "/home/ubuntu"
  creates "/home/ubuntu/clean_db.sql"
#  notifies :run, resources(:execute  => "import database")
end

execute "copy backup database" do
  command "cp /db-backup/home/ubuntu/clean_db.sql.gz /home/ubuntu/"
  creates "/home/ubuntu/clean_db.sql"
  notifies :run, resources(:execute  => "unpack_database_file"), :immediately
  action :run
end

#execute "create and import database" do
#  command "mysqladmin -uroot -p#{node[:mysql][:server_root_password]} create #{node[:mysql][:server_app_database]} && mysql -uroot -p#{node[:mysql][:server_root_password]} #{node[:mysql][:server_app_database]} < clean_db.sql"
#  action :run
#  not_if "mysql -uroot -p#{node[:mysql][:server_root_password]} -e \"show databases;\" | grep #{node[:mysql][:server_app_database]}"
#end

execute "create database" do
  command "mysqladmin -uroot -p#{node[:mysql][:server_root_password]} create #{node[:mysql][:server_app_database]}"
  action :run
  not_if "mysql -uroot -p#{node[:mysql][:server_root_password]} -e \"show databases;\" | grep #{node[:mysql][:server_app_database]}"
end

#this should be only done for the dev environment. No old message should be sent out.
execute "deleting mailmessage table" do
  command "mysql -uroot -p#{node[:mysql][:server_root_password]} #{node[:mysql][:server_app_database]} -e \"truncate mailmessage;\""
  action :nothing
end

##wc -l returns currently (4/27/2011) 485 lines - there are 484 tables in the magento schema
execute "import database" do
  command "mysql -uroot -p#{node[:mysql][:server_root_password]} #{node[:mysql][:server_app_database]} < clean_db.sql"
  cwd "/home/ubuntu"
  action :run
  not_if "[ `mysql -uroot -p#{node[:mysql][:server_root_password]} #{node[:mysql][:server_app_database]} -e \"show tables;\" | wc -l` -gt 484 ]"
  notifies :run, resources(:execute  => "deleting mailmessage table")
end

execute "grant privileges" do
  command "mysql -uroot -p#{node[:mysql][:server_root_password]} -e \"GRANT ALL PRIVILEGES ON *.* TO 'app'@'%' identified by '#{node[:mysql][:server_app_password]}';FLUSH PRIVILEGES;\""
  action :run
end

execute "enable sailthru" do
  command "mysql -uroot -p#{node[:mysql][:server_root_password]} #{node[:mysql][:server_app_database]} -e \"update core_config_data set value = '1' where path = 'system/sailthru/enabled';\""
  action :run
end


#that's the time it takes 04/27/2011
##Chef Run complete in 2696.520229 seconds


