#
# Cookbook Name:: mysql
# Recipe:: db_server
#
# Copyright 2011, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

include_recipe "zzz_mysql::install_fog"
if node['mysql']['server_type'] == "master" then
    if node['aws'] == nil ||  node['aws']['ebs_volume'] == nil || node['aws']['ebs_volume']['mysql_data_volume'] == nil || node['aws']['ebs_volume']['mysql_data_volume']['volume_id'] == nil then	
	include_recipe "zzz_mysql::create_ebs_volume"
    end
end

include_recipe "zzz_mysql::server"
include_recipe "zzz_mysql::install_scripts"
include_recipe "zzz_mysql::db_backup"
include_recipe "zzz_mysql::configurations"
if node['mysql']['server_type'] == "slave" then
        if node['mysql']['snapshot_id'] != "" then
                include_recipe "zzz_mysql::create_ebs_volume"
        end
end

include_recipe "zzz_mysql::server_ec2"
#include_recipe "mysql::db_backup"
#include_recipe "mysql::test"


#during bootstrap this service is not start if the service is call "mysql". The reason might be that the service was defined before and the definition before is used....
service "mysql_final" do
  service_name value_for_platform([ "centos", "redhat", "suse", "fedora" ] => {"default" => "mysqld"}, "default" => "mysql")
  if (platform?("ubuntu") && node.platform_version.to_f >= 10.04)
    restart_command "restart mysql"
    stop_command "stop mysql"
    start_command "start mysql"
    status_command "status mysql | grep running"
  end
  supports :status => true, :restart => true, :reload => true
  action :start
end

# create the initial snapshot for master mysql machine
#if node['mysql']['server_type'] == "master" then
# if (node.attribute?('ec2') && ! FileTest.directory?(node['mysql']['ec2_path'])) then
#  script "create initial snapshot" do
#    interpreter "bash"
#    user "root"
#    cwd "/home/ubuntu"
#    code <<-EOH
#       ./create-snapshot.sh >> snapshot_create.log
#    EOH
#  end
# end
#end
