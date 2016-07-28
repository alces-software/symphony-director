#!/usr/bin ruby

# Listing required resources
# require 'open3'

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

node_type = ARGV[0]
quantity = ARGV[1]
base_name = ARGV[2]
ip_quad_3_range_low = ARGV[3]
ip_quad_3_range_high = ARGV[4]
ip_quad_4_range_low = ARGV[5]
ip_quad_4_range_high = ARGV[6]





validation_error =false

# Input validation
if node_type.to_s == nil
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

if (ip_quad_3_range_low.to_i < 0) || (ip_quad_3_range_high.to_i > 255)
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

if ((ip_quad_3_range_high.to_i - ip_quad_3_range_low.to_i) * (ip_quad_4_range_high.to_i - ip_quad_4_range_low.to_i)) < quantity.to_i
  puts 'The IP ranges supplied do not provide enough IP addresses for the quantity of nodes desired. Please select a larger range or request fewer nodes.'
  validation_error = true
end



# Proceed to preparation and building of nodes
if !validation_error

  # Read site config file into environment variables
  File.readlines "#{Dir.pwd}/config/site" do |line|
    key, value = line.split '='
    ENV[key] = value
  end

  # Read host config file into environment variables
  File.readlines "#{Dir.pwd}/config/host" do |line|
    key, value = line.split '='
    ENV[key] = value
  end


  # Read config file of node type specified by user
  File.readlines "#{Dir.pwd}/config/#{node_type}" do |line|
    key, value = line.split '='
    ENV[key] = value
  end


  # Start loop of quantity of nodes
  for nodeNum in 1..quantity
    ## Build node

    `cobbler system add --name #{base_name}#{nodeNum} --hostname #{base_name}#{nodeNum}.#{ENV[PRVDOMAIN]} --profile #{ENV[PROFILE]} --name-servers-search "#{ENV[SEARCHDOMAIN]}" --name-servers=10.78.254.1 --gateway=#{ENV[GW]}`


    `cobbler system edit --name #{base_name}#{nodeNum} --hostname #{base_name}#{nodeNum}.#{ENV[PRVDOMAIN]} --profile #{ENV[PROFILE]} --name-servers-search "#{ENV[SEARCHDOMAIN]}" --name-servers=10.78.254.1 --gateway=#{ENV[GW]}`


    ## Create Bonds

    ## Create Bridges

    ## Configure networks

    ## Configure disks

    ##


    ## Output build progress of node

  end
else

end





# End loop









