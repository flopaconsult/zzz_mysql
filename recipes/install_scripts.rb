# copies all scripts to node['mysql']['scripts_location']
# these scripts will be necessary for slave or master creation 

directory node['mysql']['scripts_location'] do
    owner "root"
    group "root"
    mode "0755"
    action :create
end


template node['mysql']['scripts_location_config'] do
    source "config.properties.erb"
    owner "root"
    group "root"
    mode "0604"
    variables :password => node['mysql']['server_root_password']
end



cookbook_file node['mysql']['scripts_location_db'] do
  source 'DataBase.rb'
  backup 5
  owner 'root'
  group 'root'
  mode 0604
end

cookbook_file node['mysql']['scripts_location_db_util'] do
  source 'DataBaseUtil.rb'
  backup 5
  owner 'root'
  group 'root'
  mode 0604
end

cookbook_file node['mysql']['scripts_location_make_master'] do
  source 'MakeMaster.rb'
  backup 5
  owner 'root'
  group 'root'
  mode 0707
end

cookbook_file node['mysql']['scripts_location_make_slave'] do
  source 'MakeSlave.rb'
  backup 5
  owner 'root'
  group 'root'
  mode 0707
end

cookbook_file node['mysql']['scripts_location_update_properties'] do
  source 'UpdatePropertyFile.rb'
  backup 5
  owner 'root'
  group 'root'
  mode 0707
end

cookbook_file node['mysql']['scripts_location_util_properties'] do
  source 'UtilProperties.rb'
  backup 5
  owner 'root'
  group 'root'
  mode 0604
end

# this search is necessary to search for all mysql machines and get the master ip, host and password
# these data will be necessary for ./MakeMaster.rb script because the script must connect to the master machine 
if node['mysql']['server_type'] == "slave" then
  #search(:node, "roles:#{node['mysql']['role']} AND app_environment:#{node['app_environment']}", nil, 0, 1) do |n|
  search(:node, "roles:#{node['mysql']['role']} ", nil, 0, 1) do |n|
    if n['mysql'] != nil then
      if n['mysql']['server_type'] == "master" then
       script "check_master" do
         interpreter "bash"
         user "root"
         cwd "#{node['mysql']['scripts_location']}"
         code <<-EOH
           ./UpdatePropertyFile.rb #{n['mysql']['server_repl_password']} #{n['ipaddress']} #{node['mysql']['server_root_password']}
           #{node['mysql']['mysql_bin']} -h #{n['ipaddress']} -u repl -e 'show slave status;' -p"#{n['mysql']['server_repl_password']}" > check_slave
           #{node['mysql']['mysql_bin']} -h #{n['ipaddress']} -u repl -e 'show master status;' -p"#{n['mysql']['server_repl_password']}" > check_master
         EOH
        end
      end
    end
  end
end
