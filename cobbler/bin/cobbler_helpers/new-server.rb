#!/usr/bin/ruby

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
ip_quad_3_range_low = ARGV[4]
ip_quad_3_range_high = ARGV[5]
ip_quad_4_range_low = ARGV[6]
ip_quad_4_range_high = ARGV[7]


