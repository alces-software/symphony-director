#!/usr/bin/ruby

# Creates a new server on cobbler

require 'yaml'


# Building configuration for server to generate
def build_config(*config_files)
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

def build_server(config, server_name, q3ip, q4ip, build_mac)

end