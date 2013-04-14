require 'rubygems'
Gem.clear_paths
require 'fog'
Gem.clear_paths 


aws = data_bag_item("aws", "main")

cookbook_file node['mysql']['scripts_location_snapshot'] do
  source 'create-master-snapshot.sh'
  backup 5
  owner 'root'
  group 'root'
  mode 0755
end


if node['mysql']['server_type'] == "slave" then

	# this part of code is not used for the moment because the snapshot creation for a remote server will not work with freeze option
        if node['mysql']['snapshot_type'] == "new_snapshot" then
                puts "CREATE NEW SNAPSHOT!"
                search(:node, "roles:#{node['mysql']['role']} AND app_environment:#{node['app_environment']}", nil, 0, 1) do |n|
                        if n['mysql'] != nil then
				# this script will check all mysql machines to find the master and in case of master a snapshot will be created
                                script "check_master_snapshot_slave" do
                                        interpreter "bash"
                                        user "root"
                                        cwd "#{node['mysql']['scripts_location']}"
                                        code <<-EOH
                                                #{node['mysql']['mysql_bin']} -h #{n['ipaddress']} -u repl -e 'show slave status;' -p"#{n['mysql']['server_repl_password']}" > check_master_snapshot
                                                ./create-master-snapshot.sh #{aws['aws_access_key']} #{aws['aws_secret_access_key']} #{n['ec2']['instance_id']} #{n['ec2']['placement_availability_zone']} #{n['mysql']['device']} #{n['mysql']['ec2_mountpoint']} #{n['environment']['name']} #{n['ec2tag']['name']} #{n['mysql']['server_root_password']} #{n['ipaddress']}
                                        EOH
                                end
                        end
                end
        end

        region = node.attribute["region"]
        snapshot_name = node['mysql']['snapshot_filter']
        attributes = {
                :provider => 'AWS',
                :aws_access_key_id => "#{aws['aws_access_key']}",
                :aws_secret_access_key => "#{aws['aws_secret_access_key']}",
                :region => region
        }

        AWS = Fog::Compute.new(attributes)

        # Grab the list of all snapshots
        snapshots  = AWS.snapshots.all


	# filters the snapshots by creation date and gets the last one created
		
	latest_snapshot = ""
        latest_snapshot_date = nil
        latest_snapshot_status = ""

        snapshots.each do |snap|
                unless snap.description.nil?
                        unless (snap.description.index(snapshot_name).nil?)
                        	if (snap.state == "completed")       
				    	snapshot_date = snap.created_at
                                    	if latest_snapshot_date.nil?
                                        	latest_snapshot = snap.id
                                        	latest_snapshot_date = snapshot_date
                                        	latest_snapshot_status = snap.state
                                    	else
                                        	if latest_snapshot_date < snapshot_date
                                                	latest_snapshot = snap.id
                                                	latest_snapshot_date = snapshot_date
                                                	latest_snapshot_status = snap.state
                                        	end
                                	end
				end
                        end
                end
        end

        ruby_block "Get last snapshot log" do
                block do
                        Chef::Log.info("Latest snapshot for slave mount is "+latest_snapshot+" from date "+latest_snapshot_date.inspect+" and status "+latest_snapshot_status)
                end
                action :create
        end

        node.set[:mysql][:snapshot_id] = latest_snapshot

	# tries to set the current server as mysql slave
	script "set as slave"  do
                interpreter "bash"
                user "root"
                cwd "#{node['mysql']['scripts_location']}"
                code <<-EOH
                        ./MakeSlave.rb
                EOH
		returns [0,1]
        end


end

# in case of mysql master server we will try to set this server as master
if node['mysql']['server_type'] == "master" then

	script "set as master"  do
                interpreter "bash"
                user "root"
                cwd "#{node['mysql']['scripts_location']}"
                code <<-EOH
                        ./MakeMaster.rb
                EOH
		returns [0,1]
        end

end

