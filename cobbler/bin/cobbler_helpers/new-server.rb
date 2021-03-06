#!/usr/bin ruby

# Listing required resources
# require 'open3'
require 'yaml'

=begin

This script is to automate generating several cobbler systems in batch with ease

=end


puts '                                                        '
puts '                                                        '
puts '       `.:/+/                                           '
puts '   ./oooo+`                                             '
puts ' `/oooooo.                                              '
puts ' /oooooo/                                               '
puts ' ooooooo-  ./o/                                         '
puts ' +oooooo/`+ooo                                          '
puts ' -oooooooooooo                                          '
puts '  :ooooooooooo. `:+:`                                   '
puts '   -+ooooooooo+:ooo`                                    '
puts '    `:ooooooooooooo.                               `.   '
puts '      `:+oooooooooo+`                              /o/  '
puts '        `-+ooooooooo+-                 :.   .+/   -ooo: '
puts '           .:+oooooooo+-`            .+o: `:ooo  :oooo+ '
puts '              `-/oooooooo/..-....-:/+ooo//oooo+/+ooooo/ '
puts '                  ./oooooooo+oooooooooooooooooooooooo/` '
puts '                    .+oooooooooo++oooooooooooooooo+:.   '
puts '                      .:/+ooooooo-`..--::::::::-.`      '
puts '                            `-:/oo+                     '
puts '                               `-.                      '
puts '                                                        '
puts '                                                        '






# Parsing parameters

# - Node type (login, master, hpcnode, etc...)
# - Quantity
# - Base name
# - IP quad 3 range
# - IP quad 4 range

template_name = ARGV[0].to_s
quantity = ARGV[1].to_i
base_name = ARGV[2].to_s
ip_quad_3_range_low = ARGV[3].to_i
ip_quad_3_range_high = ARGV[4].to_i
ip_quad_4_range_low = ARGV[5].to_i
ip_quad_4_range_high = ARGV[6].to_i





validation_error = false

# Input validation
if template_name.to_s == nil
  puts 'A node type (config file name) has not been supplied.'
  validation_error = true
end

if (quantity == nil) || (quantity.to_i == 0)
  puts 'A node quantity has not been supplied.'
  validation_error = true
end

if quantity.to_i < 1
  puts 'The quantity of  nodes supplied is too low ( < 1 ).'
  validation_error = true
end

if (ip_quad_3_range_low.to_i < 0) || (ip_quad_3_range_high.to_i > 254)
  puts 'The IP range for quad 3 is out of range. The lowest cannot be any lower than 0 and the highest cannot be any higher than 255.'
  validation_error = true
end

if ip_quad_3_range_low.to_i > ip_quad_3_range_high.to_i
  puts 'The lowest range for IP quad 3 cannot be higher than the highest range for IP quad 3.'
  validation_error = true
end

if (ip_quad_4_range_low.to_i < 0) || (ip_quad_4_range_high.to_i > 255)
  puts 'The IP range for quad 4 is out of range. The lowest cannot be any lower than 0 and the highest cannot be any higher than 255.'
  validation_error = true
end

if ip_quad_4_range_low.to_i > ip_quad_4_range_high.to_i
  puts 'The lowest range for IP quad 4 cannot be higher than the highest range for IP quad 3.'
  validation_error = true
end

if ((((ip_quad_3_range_high.to_i - ip_quad_3_range_low.to_i) + 1) / 2) * ((ip_quad_4_range_high.to_i - ip_quad_4_range_low.to_i) + 1)) < quantity.to_i
  puts 'The IP ranges supplied do not provide enough IP addresses for the quantity of nodes desired. Please select a larger range or request fewer nodes.'
  validation_error = true
end



# Proceed to preparation and building of nodes
if !validation_error

  puts 'Main application!'

  # Loading site configuration from YAML file
  config = YAML.load_file("#{Dir.pwd}/config/site.yml")

  # Updating configuration with host config values
  YAML.load_file("#{Dir.pwd}/config/host.yml").each {
      |key, value|

    config[key] = value
  }

  # Updating configuration with user selected template configuration
  YAML.load_file("#{Dir.pwd}/config/#{template_name}.yml").each {
      |key, value|

    config[key] = value
  }


  # Config corrections
  config["PRVDOMAIN"] = "prv.#{config["DOMAIN"]}"
  config["MGTDOMAIN"] = "mgt.#{config["DOMAIN"]}"
  config["BUILDDOMAIN"] = "bld.#{config["DOMAIN"]}"
  config["IBDOMAIN"] = "ib.#{config["DOMAIN"]}"
  config["DMZDOMAIN"] = "dmz.#{config["DOMAIN"]}"

  config["IDM"] = "directory.#{config["BUILDDOMAIN"]}"

  config["SEARCHDOMAIN"][0] = config["PRVDOMAIN"]
  config["SEARCHDOMAIN"][1] = config["IBDOMAIN"]
  config["SEARCHDOMAIN"][2] = config["MGTDOMAIN"]
  config["SEARCHDOMAIN"][4] = config["BUILDDOMAIN"]


  config.each do |k, v|
    puts "#{k}: #{v}"
  end


  # Start loop of quantity of nodes
  quantity.times do |i|
    puts i

    # Adding the system to cobbler
    #`cobbler system add --name #{base_name}#{i} --hostname #{base_name}#{i}.#{config["PRVDOMAIN"].to_s} --profile #{config["PROFILE"].to_s} --name-servers-search "#{config["SEARCHDOMAIN"].to_s}" --name-servers=10.78.254.1 --gateway=#{config["GW"].to_s}`

  end

=begin

  for node_num in 1..quantity
    ## Build node

    `cobbler system add --name #{base_name}#{node_num} --hostname #{base_name}#{node_num}.#{ENV[PRVDOMAIN]} --profile #{ENV[PROFILE]} --name-servers-search "#{ENV[SEARCHDOMAIN]}" --name-servers=10.78.254.1 --gateway=#{ENV[GW]}`


    `cobbler system edit --name #{base_name}#{node_num} --hostname #{base_name}#{node_num}.#{ENV[PRVDOMAIN]} --profile #{ENV[PROFILE]} --name-servers-search "#{ENV[SEARCHDOMAIN]}" --name-servers=10.78.254.1 --gateway=#{ENV[GW]}`


    ## Create Bonds

    ## Create Bridges

    ## Configure networks

    ## Configure disks

    ##


    ## Output build progress of node

    `cobbler system report --name #{base_name}#{node_num}`

  end

=end
else
  puts "Validation has not passed successfully. Please address the stated issues before trying again. Thank you."
end





# End loop









