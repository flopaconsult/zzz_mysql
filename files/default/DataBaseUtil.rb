#!/usr/bin/ruby

require 'rubygems'
require 'mysql'

class DataBaseUtil


        def getDataBaseConnection(host,user,pass)
                puts "MySQL connection !"

                begin
                        con = Mysql.new(host, user, pass)
                rescue Mysql::Error
                        puts "We could not connect to MySQL !"
                        exit 1
                end

                return con

        end
end

