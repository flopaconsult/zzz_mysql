include_recipe "aws"
include_recipe "xfs"

directory node['mount']['point'] do
  action 		:create
  recursive 		true
  mode 			0755
  owner 		"root"
  group 		"root"
end

#update ubuntu packages
if platform?(%w{ ubuntu })
        e = execute "update_ubuntu"  do
          command "sudo apt-get update"
          action :nothing
        end
        e.run_action(:run)
end

#install ruby
e = package "ruby"  do
  action :nothing
end
e.run_action(:install)

#install ruby-dev
e = package "ruby-dev"  do
  action :nothing
end
e.run_action(:install)

include_recipe "mysql::install_fog"

require 'rubygems'
Gem.clear_paths
require 'fog'

aws = data_bag_item("aws", "main")

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

latest_snapshots = ""
latest_snapshots_date = nil
latest_snapshots_status = ""

first_snapshot = "true"
snapshots.each do |snap|
       unless snap.description.nil?
             unless (snap.description.index(snapshot_name).nil?)
                   if (snap.state == "completed")
                          puts "Snapshot id is #{snap.id}"
                          snapshot_date = snap.created_at
                          if latest_snapshots_date.nil?
                                if node['mysql']['raid'] == "true"
				       if first_snapshot == "true" 
					      first_snapshot = "false"
                                       	      latest_snapshots = snap.id
				       else
					      latest_snapshots = latest_snapshots +", "+snap.id
				       end
                                else
                                       latest_snapshots = snap.id
                                end
                                       latest_snapshots_date = snapshot_date
                                       latest_snapshots_status = snap.state
                          else
                                if latest_snapshots_date < snapshot_date
                                       if node['mysql']['raid'] == "true"
				               if first_snapshot == "true"
                                                    first_snapshot = "false"
                                                    latest_snapshots = snap.id
                                               else
                                                    latest_snapshots = latest_snapshots +", "+snap.id
                                               end		
                                       else
                                               latest_snapshots = snap.id
                                       end
                                       latest_snapshots_date = snapshot_date
                                       latest_snapshots_status = snap.state
                                 end
                           end
                    end
             end
       end
end

ruby_block "Get last snapshots for RAID mount" do
       block do
             Chef::Log.info("Latest snapshots for mount are "+latest_snapshots+" from date "+latest_snapshots_date.inspect+" and status "+latest_snapshots_status)
       end
       action :create
end

raid_snapshots = node['restore']['snapshots']

ruby_block "Get snapshots id from attributes" do
       block do
             Chef::Log.info("Snapshots received from attributes for mount are "+raid_snapshots)
       end
       action :create
end

if latest_snapshots != nil && latest_snapshots != "" 
	raid_snapshots = latest_snapshots	
end

ruby_block "Get snaphosts the will be used for RAID mount" do
       block do
             Chef::Log.info("Snapshots that will be used for RAID mount are : "+raid_snapshots)
       end
       action :create
end

#actions : auto_attach, restore_attach
#in case of auto_attach action the snapshots parameter will be ignored
#in case of restore_attach action disk_count will be ignored 
aws_ebs_raid "create_raid" do
	mount_point 		node['mount']['point']
	disk_count 		node['mount']['disk_count']
	disk_size 		node['mount']['disk_size']
	snapshots 		raid_snapshots
	mount_options 		node['mount']['options']
	action			[:restore_attach]
	#action			[:auto_attach]
end

aws = data_bag_item("aws", "main")

template node['consistent_snapshot']['location'] do
  source "create_consistent_snapshot.sh.erb"
  owner "root"
  group "root"
  mode "0766"
  variables(
  	:aws_access_key => aws['aws_access_key'],
	:aws_secret_access_key => aws['aws_secret_access_key'],
	:mount_point => node['mount']['point'],
	:private_key => node['pk']['home_file'],
	:cert => node['cert']['home_file'],
	:consistent_snapshot => node['consistent']['snapshot'],
	:db_password => node[:mysql][:server_root_password]
  )
end

directory node['cert']['home'] do
    owner "root"
    group "root"
    mode "0755"
    action :create
end

cookbook_file node['cert']['home_file'] do
  source "cert-tu-snapshot.pem"
  owner "root"
  group "root"
  mode "0700"
end

cookbook_file node['pk']['home_file'] do
  source "pk-tu-snapshot.pem"
  owner "root"
  group "root"
  mode "0700"
end

# cron for create consistent snapshot
cron "create_consistent_snapshot" do
  minute 	node[:consistent_snapshot][:minute]
  hour 		node[:consistent_snapshot][:hour]
  day 		node[:consistent_snapshot][:day]
  month 	node[:consistent_snapshot][:month] 
  weekday 	node[:consistent_snapshot][:weekday] 
  command 	node[:consistent_snapshot][:command] 
  user 		node[:consistent_snapshot][:user]
end

if platform?("ubuntu")
	
	bash "install java 7" do
	  user "root"
	  cwd "/tmp"
	  code <<-EOH
		add-apt-repository ppa:webupd8team/java
		apt-get update
		apt-get install oracle-java7-installer -y
	  EOH
	end
	
	package "openjdk-7-jre" do
		action :install
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
end	

if platform?("centos")
	package "gcc" do
		action :install
	end

	package "zlib" do
		action :install
	end

	package "zlib-devel" do
		action :install
	end

	package "ruby" do
		action :install
	end

	package "e2fsprogs" do
		action :install
	end

	package "unzip" do
		action :install
	end

	package "MAKEDEV" do
		action :install
	end

	package "xfsprogs" do
		action :install
	end

	bash "install ec2 tools" do
	  user "root"
	  cwd "/tmp"
	  code <<-EOH
			mkdir /tmp
			mkdir -p /root/.ec2
			mkdir -p /opt/EC2TOOLS /data /opt/EC2YUM
		
			curl -o /tmp/ec2-api-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip
			unzip /tmp/ec2-api-tools.zip
			cp -r /tmp/ec2-api-tools-*/* /opt/EC2TOOLS
			
			curl -o /tmp/ec2-ami-tools.zip http://s3.amazonaws.com/ec2-downloads/ec2-ami-tools.zip
			unzip ec2-ami-tools.zip
			cp -r /tmp/ec2-ami-tools-*/* /opt/EC2TOOLS
	  EOH
	end
	
	bash "enable repository for ec2 consistent snapshot" do
	  user "root"
	  cwd "/tmp"
	  code <<-EOH
			wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-7.noarch.rpm
			sudo rpm -Uvh epel-release-6*.rpm
			yum --enablerepo=epel install perl-Net-Amazon-EC2 perl-File-Slurp perl-DBI perl-DBD-MySQL perl-Net-SSLeay perl-IO-Socket-SSL perl-Time-HiRes perl-Params-Validate -y
	  EOH
	end
	
	bash "install ec2-consistent-snapshot" do
	  user "root"
	  cwd "/tmp"
	  code <<-EOH
			wget -O /opt/aws/bin/ec2-consistent-snapshot http://bazaar.launchpad.net/~alestic/ec2-consistent-snapshot/trunk/download/head:/ec2consistentsnapsho-20090928015038-9m9x0fc4yoy54g4j-1/ec2-consistent-snapshot
			chmod 0775 /opt/aws/bin/ec2-consistent-snapshot
	  EOH
	end
	
	file "/root/.bashrc" do
	  content <<-EOS
		export PATH=\$PATH:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin:/opt/EC2TOOLS/bin
		export EC2_HOME=/opt/EC2TOOLS
		export EC2_PRIVATE_KEY=~/.ec2/pk-tu-snapshot.pem
		export EC2_CERT=~/.ec2/cert-tu-snapshot.pem
		export JAVA_HOME=/usr
	  EOS
	  mode 0755
	end
	
	execute "reload bashrc" do
		command "source ~/.bashrc"
	end
				
end



