#!/usr/bin/ruby

require 'rubygems'

class UtilProperties

        def load_properties(properties_filename)
                properties = {}
                File.open(properties_filename, 'r') do |properties_file|
                        properties_file.read.each_line do |line|
                                line.strip!
                                if (line[0] != ?# and line[0] != ?=)
                                        i = line.index('=')
                                        if (i)
                                                properties[line[0..i - 1].strip] = line[i + 1..-1].strip
                                        else
                                                properties[line] = ''
                                        end
                                end
                        end
                end
                return properties
        end

	attr_accessor :file, :properties

	def initialize(file)
    		@file = file
    		@properties = {}

    		begin
      			IO.foreach(file) do |line|
        			@properties[$1.strip] = $2 if line = ~ /([^=]*)=(.*)\/\/(.*)/ || line =~ /([^=]*)=(.*)/
      			end
    		rescue
    		end
  	end

  	def to_s
    		output = "File name #{@file}\n"
    		@properties.each { |key, value| output += " #{key} = #{value}\n" }
    		output
  	end

  	def add(key, value = nil)
    		return unless key.length > 0
    		@properties[key] = value
  	end

  	def remove(key)
    		return unless key.length > 0
    		@properties.delete(key)
  	end

  	def save
    		file = File.new(@file, "w+")
    		@properties.each { |key, value| file.puts "#{key}=#{value}\n" }
    		file.close
  	end

end

