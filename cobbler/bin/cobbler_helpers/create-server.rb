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

  return config
end

# Building individual server as part of set
def build_server(config, server_name, q3ip, q4ip, build_mac)

  # Setting quad 3 of IP address
  config["IPBUILD"].sub! "--IPQUAD3--", q3ip.to_s
  config["IPBMC"].sub! "--IPQUAD3--", q3ip.to_s
  config["IPMGT"].sub! "--IPQUAD3P1--", (q3ip + 1).to_s
  config["IPPRV"].sub! "--IPQUAD3--", q3ip.to_s
  config["IPIB"].sub! "--IPQUAD3--", q3ip.to_s

  # Setting quad 4 of IP address
  config["IPBUILD"].sub! "--IPQUAD4--", q4ip.to_s
  config["IPBMC"].sub! "--IPQUAD4--", q4ip.to_s
  config["IPMGT"].sub! "--IPQUAD4--", q4ip.to_s
  config["IPPRV"].sub! "--IPQUAD4--", q4ip.to_s
  config["IPIB"].sub! "--IPQUAD4--", q4ip.to_s


end