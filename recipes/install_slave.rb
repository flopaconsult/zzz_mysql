require 'rubygems'
Gem.clear_paths
require 'fog'


aws = data_bag_item("aws", "main")

cookbook_file node['mysql']['scripts_location_snapshot'] do
  source 'create-master-snapshot.sh'
  backup 5
  owner 'root'
  group 'root'
  mode 0755
end


if node['mysql']['server_type'] == "slave" then

	if node['mysql']['snapshot_type'] == "new_snapshot" then
		puts "CREATE NEW SNAPSHOT!"
 		search(:node, "roles:#{node['mysql']['role']} AND app_environment:#{node['app_environment']}", nil, 0, 1) do |n|
  			if n['mysql'] != nil then
puts "create snapshot data : #{aws['aws_access_key']} #{aws['aws_secret_access_key']} #{n['ec2']['instance_id']} #{n['ec2']['placement_availability_zone']} #{n['mysql']['device']} #{n['mysql']['ec2_mountpoint']} #{n['environment']['name']} #{n['ec2tag']['name']} #{n['mysql']['server_root_password']}"
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

	latest_snapshot = ""
	latest_snapshot_date = nil
	latest_snapshot_status = ""

	snapshots.each do |snap|
		unless snap.description.nil?
			puts " >>>>>>>>>>>>>>>>>>> STATUS "+snap.status
			unless (snap.description.index(snapshot_name).nil?) 
				snapshot_date = snap.created_at
				if latest_snapshot_date.nil?
					latest_snapshot = snap.id
					latest_snapshot_date = snapshot_date
					latest_snapshot_status = snap.status
				else
					if latest_snapshot_date < snapshot_date
						latest_snapshot = snap.id
						latest_snapshot_date = snapshot_date
						latest_snapshot_status = snap.status
					end
				end
			end
		end
	end

        ruby_block "Get last snapshot log" do
                block do
        	        Chef::Log.error("Latest snapshot for slave mount is "+latest_snapshot+" from date "+latest_snapshot_date.inspect+" and status "+latest_snapshot_status)
                end
        	action :create
        end

	
	node.set[:mysql][:snapshot_id] = latest_snapshot

end

if node['mysql']['server_type'] == "master" then

	 script "check_master_snapshot_slave" do
                interpreter "bash"
                user "root"
                cwd "#{node['mysql']['scripts_location']}"
                code <<-EOH
                        ./create-master-snapshot.sh #{aws['aws_access_key']} #{aws['aws_secret_access_key']} #{node['ec2']['instance_id']} #{node['ec2']['placement_availability_zone']} #{node['mysql']['device']} #{node['mysql']['ec2_mountpoint']} #{node['environment']['name']} #{node['ec2tag']['name']} #{node['mysql']['server_root_password']} #{node['ipaddress']}
                EOH
        end

end
