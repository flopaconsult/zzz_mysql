#!/usr/bin/ruby

require 'rubygems'
require 'UtilProperties'

repl_password = ARGV[0]
repl_host = ARGV[1]
password = ARGV[2]

property = UtilProperties.new('config.properties')
if repl_password != nil
      property.add('mysql_replication_password',repl_password)
end
if repl_host != nil
      property.add('mysql_replication_host',repl_host)
end
if password != nil
      property.add('password',password)
end

property.save

