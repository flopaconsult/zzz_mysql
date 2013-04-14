#
# Cookbook Name:: mysql
# Recipe:: default
#
# Copyright 2008-2009, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

service "mysql" do
  service_name value_for_platform([ "centos", "redhat", "suse", "fedora" ] => {"default" => "mysqld"}, "default" => "mysql")
  if (platform?("ubuntu") && node.platform_version.to_f >= 10.04)
    restart_command "restart mysql"
    stop_command "stop mysql"
    start_command "start mysql"
  end
  supports :status => true, :restart => true, :reload => true
  action :nothing
end

if node['mysql']['server_type'] == "master" then

 if (node.attribute?('ec2') && ! FileTest.directory?(node['mysql']['ec2_path'])) then

  service "mysql" do
    action :stop
    not_if "service mysql status | grep stop/waiting"
  end

  # moves all data from mysql lib directory to the mount poin. this will be necessary for snapshot creation
  script "move mysql data directory to EBS volume" do
    interpreter "bash"
    user "root"
    cwd "#{node['mysql']['data_dir']}"
    code <<-EOH
	mv * #{node['mysql']['ec2_path']}
    EOH
  end


#  this command is not working properly !!! replaced with the above one

#  execute "move mysql data directory to EBS volume" do
#    command "mv #{node['mysql']['data_dir']} #{node['mysql']['ec2_path']}"
#    not_if do FileTest.directory?(node['mysql']['ec2_path']) end
#  end

  [node['mysql']['ec2_path'], node['mysql']['data_dir']].each do |dir|
    directory dir do
      owner "mysql"
      group "mysql"
    end
  end


  directory node['mysql']['ec2_path'] do
    owner "mysql"
    group "mysql"
    mode 0755
  end

  #re-created the directory which was moved
  directory node['mysql']['data_dir'] do
    owner "mysql"
    group "mysql"
  end


  # this mount seems to have in Chef 0.9.16 a bug. Statements after the mount are not getting executed and even the notifies command does NOT run!
  # seems that this problem is not for Chef 0.9.16 ( I used it for this Chef version). The statements after this command were not executed because 
  # of mv command above ( it was replaced ). The notifications are also working now.
  mount node['mysql']['data_dir'] do
    device node['mysql']['ec2_path']
    fstype "none"
    options "bind,rw"
    action :mount
    notifies :start, resources(:service => "mysql"), :immediately
  end
  
# if the command mount above is working we won't need this block

#test: does it help to get the mysql service started?
#  ruby_block "wait for mount"  do
#    block do
#      sleep(2)
#    end
#    action :create
#  end


# if the command mount above is working we won't need this block

#TODO: FIX
#in the log output this statement never shows up (the database is not restarted), why?
# service "mysql" do
#   action :start
# end



 end


 mountpoint = "#{node[:mysql][:ec2_path]} #{node['mysql']['data_dir']} none rw,bind 0 0"

 execute "\"add EBS mysql mount to fstab\"" do
   command "echo #{mountpoint} >> /etc/fstab"
   not_if "cat /etc/fstab | grep \"#{mountpoint}\""
 end


end

if node['mysql']['server_type'] == "slave"  then
	if node['mysql']['snapshot_id'] == "" then
		ruby_block "No snapshot ERROR" do
		  	block do
     				Chef::Log.error("NO SNAPSHOT TO BE MOUNTED AT THIS MOMENT. PLEASE TRY AGAIN LATER. NO SNAPSHOT WITH STATE COMPLETED WAS FOUND.")
   		   	end
   			action :create
		end
	end
end


#in case of slave server we have to mount back the backup snapshot 
if node['mysql']['server_type'] == "slave" && node['mysql']['snapshot_id'] != "" then
  if (node.attribute?('ec2') && ! FileTest.directory?(node['mysql']['ec2_path']))
	service "mysql" do
		action :stop
		not_if "service mysql status | grep stop/waiting"
	end

	mount node['mysql']['data_dir'] do
    		device node['mysql']['ec2_path']
    		fstype "none"
    		options "bind,rw"
    		action :mount
    		notifies :start, resources(:service => "mysql"), :immediately
	end

	service "mysql" do
	   action :start
	end

   end
end
