#!/usr/bin/ruby

require 'rubygems'
        
require 'mysql'
require 'DataBaseUtil'
require 'UtilProperties'

class DataBase

        def makeMaster

                configProperties = UtilProperties.new('config.properties')
                config = configProperties.load_properties('config.properties')

                begin
                        dataBaseUtil = DataBaseUtil.new()
                        con = dataBaseUtil.getDataBaseConnection(config['host'],config['user'],config['password'])
                rescue Mysql::Error
                        puts "We could not connect to this database."
                        exit 1
                end

                begin
                        # We need to check if this EBS snapshot came from a slave. If it did, then we need to make it a master.
                        check_status = con.query "show slave status"
                        slave_sql_running = "No"
                        puts " Number of results : "+check_status.num_rows().to_s

                        if check_status.num_rows() > 0
                                slave_sql_running = "Yes"
                        end

                        if slave_sql_running == "Yes"
                                puts "This is SLAVE => converting slave to master"
                                con.query "STOP SLAVE"
                                con.query "CHANGE MASTER TO MASTER_HOST=''"
                                con.query "RESET MASTER"
                                con.query "FLUSH LOGS"
                        else
                                puts "This is not SLAVE => already configured as master"
                        end

                        check_status.free
                ensure
                        con.close
                end
        end


        def makeSlave
                dataBaseUtil = DataBaseUtil.new()
                configProperties = UtilProperties.new('config.properties')
                config = configProperties.load_properties('config.properties')

		master =  configProperties.load_properties('/mnt/mysql/master_status')

                begin
                        con = dataBaseUtil.getDataBaseConnection(config['host'],config['user'],config['password'])
                rescue Mysql::Error
                        puts "We could not connect to this database."
                        exit 1
                end

                begin
                        slave_sql_running = "No"
                        # We need to check if this EBS snapshot came from a slave. If it did, then we can only start slave.
                        check_status = con.query "show slave status"
                        puts " Number of results : "+check_status.num_rows().to_s

                        if check_status.num_rows() > 0
                                slave_sql_running = "Yes"
                        end

                        mysql_replication_host = config['mysql_replication_host']
                        mysql_replication_username = config['mysql_replication_username']
                        mysql_replication_password = config['mysql_replication_password']

                        if slave_sql_running == "Yes"
                                con.query "STOP SLAVE"
                                con.query "CHANGE MASTER TO MASTER_HOST='"+mysql_replication_host+"', MASTER_USER='"+mysql_replication_username+"', MASTER_PASSWORD='"+mysql_replication_password+"'"
                                con.query "START SLAVE"
                                con.query "RESET MASTER"
                                con.query "FLUSH LOGS"
                        else
                                master_log_pos = ""
                                master_log_file = ""

                                begin
                                        master_con = dataBaseUtil.getDataBaseConnection(mysql_replication_host,mysql_replication_username,mysql_replication_password)
                                rescue Mysql::Error
                                        puts "We could not connect to this database."
                                        exit 1
                                end


 	                        master_snapshot_pos = ""
                                master_snapshot_file = ""

                                check_master = master_con.query "show master status"
                                is_master = "false"
                                if check_master.num_rows() > 0
                                        is_master = "true"
					# get master log position and master log file from last snapshot
					master_snapshot_pos = master['master_log_pos']
                                        master_snapshot_file = master['master_log_file']

                                        master_log_pos = master_snapshot_pos.gsub("\"","")
                                        master_log_file = master_snapshot_file.gsub("\"","")

					if (( master_log_pos == nil || master_log_pos == "" ) && ( master_log_file == nil || master_log_file == ""  )) then
						check_master.each_hash do |row|
        	                                        master_log_pos = row['Position']
                	                                master_log_file = row['File']
                                	        end
					end
                                end

                                if is_master == "false"
                                        con.query "GRANT RELOAD ON *.* TO '"+mysql_replication_username+"'@'%'"
                                        con.query "GRANT SUPER ON *.* TO '"+mysql_replication_username+"'@'%'"
                                        con.query "FLUSH PRIVILEGES"
                                end

                                con.query "CHANGE MASTER TO MASTER_HOST='"+mysql_replication_host+"', MASTER_USER='"+mysql_replication_username+"', MASTER_PASSWORD='"+mysql_replication_password+"', MASTER_LOG_FILE='"+master_log_file+"', MASTER_LOG_POS="+master_log_pos.to_s
                                con.query "START SLAVE"
                                con.query "RESET MASTER"
                                con.query "FLUSH LOGS"

                                stop = "false"
                                while stop=="false" do
                                        check_status = con.query "show slave status"
                                        puts " Number of results for slave : "+check_status.num_rows().to_s
                                        if check_status.num_rows() > 0
                                                check_status.each_hash do |row|
                                                        secondsBehindMaster = row['Seconds_Behind_Master']
                                                        puts " Read_Master_Log_Pos "+row['Read_Master_Log_Pos']
                                                        puts " Seconds_Behind_Master "+secondsBehindMaster.to_s
                                                        if row['Last_IO_Error'] != ""
                                                                puts " Last_IO_Error "+row['Last_IO_Error']
								puts "START SUDO CHEF-CLIENT!!!"
								`sudo chef-client`
								`/home/ubuntu/scripts/MakeSlave.rb`
								break
								
                                                        end
                                                        if row['Slave_IO_State'] == "Connecting to master"
                                                                sleep 2
                                                        end
                                                        if secondsBehindMaster == nil
                                                                if row['Last_SQL_Error'] != nil && row['Last_SQL_Error'] != ""
                                                                        puts " Last_SQL_Error "+row['Last_SQL_Error']
                                                                end
                                                                sleep 2
                                                        elsif secondsBehindMaster.to_s == ""
                                                                sleep 2
                                                        elsif secondsBehindMaster.to_i > 0
                                                                sleep 1
                                                        elsif secondsBehindMaster.to_i == 0
                                                                stop = "true"
                                                                break
                                                        end

                                                end
                                        end
                                end

                        end


                        check_status.free
                ensure
                        con.close
                end

        end

	def getIpNumber(ip_address)	
		ip_number = 0;	
		ip_address.split('.').reverse.each_with_index do |elem, i|
			ip_number = ip_number + 256**i * elem.to_i
		end
		return ip_number.to_s
	end


end

