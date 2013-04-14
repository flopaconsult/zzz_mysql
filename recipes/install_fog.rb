e = execute "aptitude update" do
  ignore_failure true
  command "apt-get update"
  action :nothing
end
e.run_action(:run) 


e = ruby_block "Aptitude update" do
  block do
    Chef::Log.info("Aptitude update was successfully executed...")
  end
  action :nothing
end
e.run_action(:create)


#install nokogiri_prereq; this is needed starting with fog 1.9.0
e = package "make"  do
  action :nothing
end
e.run_action(:install)

#install nokogiri_prereq
e = package "libxslt-dev"  do
  action :nothing
end
e.run_action(:install) 

#install nokogiri_prereq
e = package "libxml2-dev"  do
  action :nothing
end
e.run_action(:install)

e = package "ruby" do
action :nothing
end
e.run_action(:install)

#install ruby-dev
e = package "ruby-dev" do
action :nothing
end
e.run_action(:install)

e = package "libssl-dev"  do
  action :nothing
end
e.run_action(:install)

e = package "libopenssl-ruby"  do
  action :nothing
end
e.run_action(:install)

# install gems
e = gem_package "rdoc" do
  action :nothing
  options "--no-rdoc --no-ri"
end
e.run_action(:install)

#e = gem_package "net-ssh" do
#  action :nothing
#  options "--no-rdoc --no-ri"
#end
#e.run_action(:install)

#e = gem_package "net-ssh-multi" do
#  action :nothing
#  options "--no-rdoc --no-ri"
#end
#e.run_action(:install)

e = gem_package "highline" do
  action :nothing
  options "--no-rdoc --no-ri"
end
e.run_action(:install)

e = gem_package "fog" do
  action :nothing
  version "1.9.0"
  options "--no-rdoc --no-ri"
end
e.run_action(:install)


e = ruby_block "Install fog" do
  block do
    Chef::Log.info("FOG library was successfully installed")
  end
  action :nothing
end
e.run_action(:create)

