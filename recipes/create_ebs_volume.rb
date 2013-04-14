#
# Cookbook Name:: mysql
# Recipe:: create_ebs_volume
#
# Copyright 2011, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

include_recipe "aws"
include_recipe "xfs"

#include access to instance_availability_zone
class Chef::Recipe
  include Opscode::Aws::Ec2
end

ebs_availability_zone = instance_availability_zone()

gem_package "right_aws"  do
  action :install
end

aws = data_bag_item("aws", node[:mysql][:databag_cred])

aws_ebs_volume "mysql_data_volume" do
  provider "aws_ebs_volume"
  aws_access_key aws['aws_access_key']
  aws_secret_access_key aws['aws_secret_access_key']
  availability_zone ebs_availability_zone # node[:ec2][:placement_availability_zone] is not set at the first run (before Ohai the instance is registered with Ohai)
  device node[:mysql][:device]
  size node[:mysql][:ebs_vol_size]
  action [:create, :attach]
  if node.attribute?("mysql") && node["mysql"].attribute?("snapshot_id")
    snapshot_id node[:mysql][:snapshot_id]
  end
end

directory "#{node[:mysql][:ec2_mountpoint]}" do
  action :create
  recursive true
  mode 0777
  owner "root"
  group "root"
end

ruby_block "wait for EBS volume to get attached"  do
  block do
    sleep(10)
  end
  action :create
end

execute "mkfs.xfs"  do
  command "mkfs.xfs #{node[:mysql][:device]}" 
  action :run
  not_if "cat /proc/mounts | grep #{node[:mysql][:device]}"
  returns [0,1] #ignore error if filesystem already exists (in this case mkfs is not executed)
end

#mount "#{node[:mysql][:ec2_mountpoint]}" do
#  device node[:mysql][:device]
#  options "rw noatime"
#  fstype "xfs"
#  action [ :enable, :mount ]
#  # Do not execute if its already mounted
#  not_if "cat /proc/mounts | grep #{node[:mysql][:ec2_mountpoint]}"
#end




#directory "/vol/etc/mysql"s do
#  action :create
#  recursive true
#  mode 0755
#  owner "root"
#  group "root"
#end
#directory "/vol/lib" do
#  action :create
#  recursive true
#  mode 0755
#  owner "root"
#  group "root"
#end
#directory "/vol/lib/mysql" do
#  action :create
#  recursive true
#  mode 0755
#  owner "root"
#  group "root"
#end
#directory "/vol/log" do
#  action :create
#  recursive true
#  mode 0755
#  owner "root"
#  group "root"
#end
#directory "/vol/log/mysql" do
#  action :create
#  recursive true
#  mode 0755
#  owner "root"
#  group "root"
#end

#cookbook_file "/etc/fstab"  do
#  source "fstab"
#  mode 0644
#  owner "root"
#  group "root"
#end

#execute "mount"  do
#  command "mount -a"
#  action :run
#end


