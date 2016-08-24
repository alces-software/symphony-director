#!/usr/bin/ruby

# Creates a cluster of new servers on cobbler

require 'yaml'
require 'open3'
require 'logger'

$logger = Logger.new(File.new('status.log'))

class Server
	def initialize(name, template, ip3, ip4, mac)
		@name = name.to_s
		@config = generate_config("default", template.to_s)
		@mac = mac.to_s
		
		set_ip_addresses(ip3, ip4)
	end

	# Public functions
	public
	
	def build_server
	
		# Adding server to cobbler
		cobbler_command("cobbler system add --name #{@name} --hostname #{@name}.#{@config["PRVDOMAIN"]} --profile #{@config["PROFILE"]} --name-servers-search #{@config["SEARCHDOMAIN"]} --name-servers=10.78.254.1 --gateway=#{@config["GW"]}")

		cobbler_command("cobbler system edit --name #{@name} --hostname #{@name}.#{@config["PRVDOMAIN"]} --profile #{@config["PROFILE"]} --name-servers-search #{@config["SEARCHDOMAIN"]} --name-servers=10.78.254.1 --gateway=#{@config["GW"]}")
		
		
		# Creating bonds
		if ! @config["BONDS"] == nil

			@config["BONDS"].each do |bond|
				options = "#{bond}OPTIONS"

				cobbler_command("cobbler system edit --name #{@name} --interface=#{bond} --interface-type=bond --bonding-opts='#{@config[options]}'")

				slaves = "#{bond}SLAVES"

				@config[slaves].each {
					|slave|

					cobbler_command("cobbler system edit --name #{@name} --interface #{slave} --interface-type=bond_slave --interface-master=#{bond}")
				}
			end
		end


		# Creating bridges
		if ! @config["BRIDGES"] == nil

			@config["BRIDGES"].each do |bridge|
				options = "#{bridge}OPTIONS"

				if @config[options] == nil
					@config[options] = "stp=no"
				end

				cobbler_command("cobbler system edit --name #{@name} --interface=#{bridge} --interface-type=bridge --bonding-opts='#{@config[options]}'")

				slaves = "#{bond}SLAVES"

				@config[slaves].each {
					|slave|

					cobbler_command("cobbler system edit --name #{server_name} --interface #{slave} --interface-type=bridge_slave --interface-master=#{bridge}")
				}
			end
		end


		cobbler_command("cobbler system edit --name #{@name} --interface #{@config["BUILD_INT"]} --dns-name=#{@name}.#{@config["BUILDDOMAIN"]} --ip-address=#{@config["IPBUILD"]} --netmask=#{@config["BUILDNETMASK"]} --static=true")


		# Setting MAC address
		if ! @mac == nil
			cobbler_command("cobbler system edit --name #{@name} --interface #{@config["BUILD_INT"]} --mac='#{@mac}'")
		end


		# Building private interface
		if ! @config["PRV_INT"] == nil
			cobbler_command("cobbler system edit --name #{@name} --interface #{@config["PRV_INT"]} --dns-name=#{@name}.#{@config["PRVDOMAIN"]} --ip-address=#{@config["IPPRV"]} --netmask=#{@config["PRVNETMASK"]} --static=true")
			if ! @config["PRV_ROUTES"] == nil
				cobbler_command("cobbler system edit --name #{@name} --interface #{@config["PRV_INT"]} --static-routes='#{@config["PRV_ROUTES"]}'")
			end
		end


		# Building Management interface
		if ! @config["MGT_INT"] == nil
			cobbler_command("cobbler system edit --name #{@name} --interface #{@config["MGT_INT"]} --dns-name=#{@name}.#{@config["MGTDOMAIN"]} --ip-address=#{@config["IPMGT"]} --netmask=#{@config["MGTNETMASK"]} --static=true")
		end

		# Building DMZ interface
		if ! @config["DMZ_INT"] == nil
			cobbler_command("cobbler system edit --name #{@name} --interface #{@config["DMZ_INT"]} --dns-name=#{@name}.#{@config["DMZDOMAIN"]} --ip-address=#{@config["IPDMZ"]} --netmask=#{@config["DMZNETMASK"]} --static=true")
		end


		# Setting machine disk
		disk_layout = "'#{@config["DISKLAYOUT"]}'"
		disk = "'#{@config["DISK"]}'"

		cobbler_command('cobbler system edit --name #{@name} --netboot=1 --in-place --ksmeta="disklayout=disk_layout disk1=disk"')

		# Setting machine serial
		if @config["HOSTTYPE"] == "vm"
			serial = "'ttyS0,115200n8'"
		else
			serial = "'ttyS1,115200n8'"
		end

		cobbler_command('cobbler system edit --name #{@name} --in-place --ksmeta="serial=#{serial}"')
		


		# Setting Disk 2 if one has been specified
		if ! @config["DISK2"] == nil
			cobbler_command("cobbler system edit --in-place --name #{@name} --ksmeta='disk2=#{@config["DISK2"]}'")
		end


		if ! @config["IDMIP"] == nil
			cobbler_command("cobbler system edit --name #{@name} --name-servers=#{@config["IDMIP"]}")
			cobbler_command("cobbler system edit --name #{@name} --in-place --ksmeta='ipa_domain=#{@config["DOMAIN"]} ipa_realm=#{@config["REALM"]} ipa_server=#{@config["IDM"]} ipa_password=#{@config["IPAPASSWORD"]}'")
		end


		if @config["HOSTTYPE"] == "hw"
			cobbler_command("cobbler system edit --name #{@name} --power-type=ipmilan --power-address=#{@config["IPBMC"]} --power-user='#{@config["IPMIUSER"]}' --power-pass='#{@config["IPMIPASSWORD"]}'")
			cobbler_command("cobbler system edit --name #{@name} --interface bmc --dns-name=#{@name}.bmc.#{@config["MGTDOMAIN"]} --ip-address=#{@config["IPBMC"]}")
			cobbler_command("cobbler system edit --name #{@name} --in-place --ksmeta 'ipmiset=true ipminetmask=#{@config["MGTNETMASK"]} ipmigateway=#{@config["GWMGT"]} ipmilanchannel=1 ipmiuserid=2'")
		end


		# Setup of infiniband adapter is available
		if ! @config["IB_INT"] == nil
			cobbler_command("cobbler system edit --name #{@name} --interface #{@config["IB_INT"]} --dns-name=#{@name}.#{@config["IBDOMAIN"]} --ip-address=#{@config["IPIB"]} --netmask=#{@config["IBNETMASK"]} --static=true")
		end

		puts "Built server " << @name
	end
	
	
	# Private functions
	private

	# Generating the configuration for the specific server
	def generate_config(*config_files)
		config = Hash.new

		# Opening configurations and adding parts to general configuration variable
		config_files.each do |config_file|
			YAML.load_file("#{Dir.pwd}/config/#{config_file}.yml").each {
				|key, value|

				config[key] = value
			}
		end

		return config
	end
	
	# Updating the ip addresses for the specifis server
	def set_ip_addresses(q3ip, q4ip)
	
		# Setting quad 3 of IP address
		@config["IPBUILD"].sub! "%IPQUAD3%", q3ip.to_s
		@config["IPBMC"].sub! "%IPQUAD3%", q3ip.to_s
		@config["IPMGT"].sub! "%IPQUAD3P1%", (q3ip.to_i + 1).to_s
		@config["IPPRV"].sub! "%IPQUAD3%", q3ip.to_s
		@config["IPIB"].sub! "%IPQUAD3%", q3ip.to_s

		# Setting quad 4 of IP address
		@config["IPBUILD"].sub! "%IPQUAD4%", q4ip.to_s
		@config["IPBMC"].sub! "%IPQUAD4%", q4ip.to_s
		@config["IPMGT"].sub! "%IPQUAD4%", q4ip.to_s
		@config["IPPRV"].sub! "%IPQUAD4%", q4ip.to_s
		@config["IPIB"].sub! "%IPQUAD4%", q4ip.to_s
		
	end
	
	def cobbler_command(command)
		
		stdout, stderr, status = Open3.capture3(command)
	
#		$logger.info("")
#		$logger.info("Server:	  " + @name)
#		$logger.info("Command:	  " + command.to_s)
#		$logger.info("Stdout:	  " + stdout.to_s)
#		$logger.info("Stderr:	  " + stderr.to_s)
#		$logger.info("Exit code:   " + status.exitstatus.to_s)
#		$logger.info("")
		
		
		puts("")
		puts("Server:	  " + @name)
		puts("Command:	  " + command.to_s)
		puts("Stdout:	  " + stdout.to_s)
		puts("Stderr:	  " + stderr.to_s)
		puts("Exit code:   " + status.exitstatus.to_s)
		puts("")
	end
end



class ServerSet
	def initialize(set_name, template, quad_3_ip_range, quad_4_ip_range, build_macs, quantity)
		@name = set_name.to_s
		@template = template.to_s
		@q3range = quad_3_ip_range.to_s
		@q4range = quad_4_ip_range.to_s
		@mac_list = build_macs.to_s
		@quantity = quantity.to_i
		
		@servers = Array.new
		
		generate_server_list
	end
	
	# Public functions
	public
	
	def build_set
		@servers.each do |server|
			server.build_server
		end
	end
	
	
	# Private functions
	private
	
	
	# Sets the quad 3 and quad 4 ip addresses based on previous ip address and available range
	def set_ip_quads(iteration, quad_3_ip_range, quad_4_ip_range)
		# Finding the highest and lowest values for quad 3 of the ip address
		quad_3_ip_range = quad_3_ip_range.split("..").map do |i| i.to_i end  #.map(&:to_i)

		# Finding the highest and lowest values for quad 4 of the ip address as well as the quantity available
		quad_4_ip_range = quad_4_ip_range.split("..").map(&:to_i)
		quad_4_ip_quantity = (quad_4_ip_range[1].to_i - quad_4_ip_range[0].to_i) + 1

		# Setting quads 3 and 4
		new_ip_quads = Array.new
		(new_ip_quads || []) << quad_3_ip_range[0].to_i + ((iteration / quad_4_ip_quantity.to_i) * 2)
		new_ip_quads << quad_4_ip_range[0].to_i + (iteration % quad_4_ip_quantity.to_i)

		return new_ip_quads
	end
	
	# Gets a set MAC address supplied via the config and returns for the corresponding server
	def set_mac_address(server_id, mac_list)
		if ! mac_list[0] == nil
			mac_list.each do |mac_record|
				if mac_record[0] == server_id
					return mac_record[1]
				end
			end
		end

		return ""
	end
	
	# Preparing servers to be build
	def generate_server_list
		@quantity.times {
			|i|

			# Setting IP address for new server
			ip_quads = set_ip_quads(i, @q3range, @q4range)

			# Building server
			(@servers || []) << Server.new(@name + "-" + i.to_s, @template, ip_quads[0], ip_quads[1], set_mac_address(i, @mac_list))
		}
	end
end




# Builds the cluster as defined in the user supplied configuration
def build_cluster(config)

	cluster = Array.new

	# Configuring server settings and generating a build list
	config.each do |set|
	
		(cluster || []) << ServerSet.new(set["server_base_name"].to_s, set["template"].to_s, set["quad3"].to_s, set["quad4"].to_s, set["build_macs"].to_a, set["quantity"].to_i)
		
	end
	
	# Building all servers as part of the cluster
	cluster.each do |set|
		set.build_set()
	end
end

config = YAML.load_file("#{Dir.pwd}/example.yml")

build_cluster(config)


