#
# Cookbook Name:: mysql
# Recipe:: test
#
# Copyright 2011, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

if node.attribute?('mysql.snapshot_id')
  Chef::Log.warn "mysql.snapshot_id"
end

if node.attribute?('mysql')
  Chef::Log.warn "mysql1"
end

if node.attribute?('mysql') && node[:mysql].attribute?("snapshot_id")
  Chef::Log.warn "mysql.snapshot_id1"
end

if node.attribute?('mysql') && node["mysql"].attribute?("snapshot_id")
  Chef::Log.warn "mysql.snapshot_id2"
end

#if node.attribute? 'mysql' && node["mysql"].attribute? "snapshot_id"
#  Chef::Log.warn "mysql.snapshot_id3"
#end

if node.attribute? "mysql" && (node["mysql"].attribute? "snapshot_id")
  Chef::Log.warn "mysql.snapshot_id4"
end


if node.has_key? "mysql"
  Chef::Log.warn "mysql2"
end


if node.has_key? "mysql" && node["mysql"].has_key?("snapshot_id")
  Chef::Log.warn "2snapshot_id1"
  Chef::Log.warn node[:mysql][:snapshot_id]
else
  Chef::Log.error node["mysql"]
end

if node.has_key? "mysql" && node[:mysql].has_key?("snapshot_id")
  Chef::Log.warn "2snapshot_id2"
  Chef::Log.warn node[:mysql][:snapshot_id]
else
  Chef::Log.error node["mysql"]
end


