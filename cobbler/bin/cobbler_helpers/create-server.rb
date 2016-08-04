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



  # Adding server to cobbler
  print `cobbler system add --name #{server_name} --hostname #{server_name}.#{config["PRVDOMAIN"]} --profile #{config["PROFILE"]} --name-servers-search #{config["SEARCHDOMAIN"]} --name-servers=10.78.254.1 --gateway=#{config["GW"]}`

  print `cobbler system edit --name #{server_name} --hostname #{server_name}.#{config["PRVDOMAIN"]} --profile #{config["PROFILE"]} --name-servers-search #{config["SEARCHDOMAIN"]} --name-servers=10.78.254.1 --gateway=#{config["GW"]}`


  # Creating bonds
  if ! config["BONDS"] == nil

    config["BONDS"].each do |bond|
      options = "#{bond}OPTIONS"

      print `cobbler system edit --name #{server_name} --interface=#{bond} --interface-type=bond --bonding-opts="#{config[options]}"`

      slaves = "#{bond}SLAVES"

      config[slaves].each {
        |slave|

        print `cobbler system edit --name #{server_name} --interface #{slave} --interface-type=bond_slave --interface-master=#{bond}`
      }
    end
  end


  # Creating bridges
  if ! config["BRIDGES"] == nil

    config["BRIDGES"].each do |bridge|
      options = "#{bridge}OPTIONS"

      if config[options] == nil
        config[options] = "stp=no"
      end

      print `cobbler system edit --name #{server_name} --interface=#{bridge} --interface-type=bridge --bonding-opts="#{config[options]}"`

      slaves = "#{bond}SLAVES"

      config[slaves].each {
          |slave|

        print `cobbler system edit --name #{server_name} --interface #{slave} --interface-type=bridge_slave --interface-master=#{bridge}`
      }
    end
  end


  print `cobbler system edit --name #{server_name} --interface #{config["BUILD_INT"]} --dns-name=#{server_name}.#{config["BUILDDOMAIN"]} --ip-address=#{config["IPBUILD"]} --netmask=#{config["BUILDNETMASK"]} --static=true`


  # Setting MAC address
  if ! build_mac == nil
    print `cobbler system edit --name #{server_name} --interface #{config["BUILD_INT"]} --mac="#{build_mac}"`
  end


  # Building private interface
  if ! config["PRV_INT"] == nil
    print `cobbler system edit --name #{server_name} --interface #{config["PRV_INT"]} --dns-name=#{server_name}.#{config["PRVDOMAIN"]} --ip-address=#{config["IPPRV"]} --netmask=#{config["PRVNETMASK"]} --static=true`
    if ! config["PRV_ROUTES"] == nil
      print `cobbler system edit --name #{server_name} --interface #{config["PRV_INT"]} --static-routes="#{config["PRV_ROUTES"]}"`
    end
  end


  # Building Management interface
  if ! config["MGT_INT"] == nil
    print `cobbler system edit --name #{server_name} --interface #{config["MGT_INT"]} --dns-name=#{server_name}.#{config["MGTDOMAIN"]} --ip-address=#{config["IPMGT"]} --netmask=#{config["MGTNETMASK"]} --static=true`
  end

  # Building DMZ interface
  if ! config["DMZ_INT"] == nil
    print `cobbler system edit --name #{server_name} --interface #{config["DMZ_INT"]} --dns-name=#{server_name}.#{config["DMZDOMAIN"]} --ip-address=#{config["IPDMZ"]} --netmask=#{config["DMZNETMASK"]} --static=true`
  end

  # Setting machine disk
  print `cobbler system edit --name #{server_name} --netboot=1 --in-place --ksmeta="disklayout='#{config["DISKLAYOUT"]}' disk1='#{config["DISK"]}'"`


  # Setting machine serial
  if config["MACHINETYPE"] == "vm"
    print `cobbler system edit --name #{server_name} --in-place --ksmeta="serial='ttyS0,115200n8'"`
  else
    print `cobbler system edit --name #{server_name} --in-place --ksmeta="serial='ttyS1,115200n8'"`
  end


  # Setting Disk 2 if one has been specified
  if ! config["DISK2"] == nil
    print `cobbler system edit --in-place --name #{server_name} --ksmeta="disk2=#{config["DISK2"]}"`
  end


  if ! config["IDMIP"] == nil
    print `cobbler system edit --name #{server_name} --name-servers=#{config["IDMIP"]}`
    print `cobbler system edit --name #{server_name} --in-place --ksmeta="ipa_domain=#{config["DOMAIN"]} ipa_realm=#{config["REALM"]} ipa_server=#{config["IDM"]} ipa_password=#{config["IPAPASSWORD"]}`
  end


  if config["HOSTTYPE"] == "hw"
    print `cobbler system edit --name #{server_name} --power-type=ipmilan --power-address=#{config["IPBMC"]} --power-user="#{config["IPMIUSER"]}" --power-pass="#{config["IPMIPASSWORD"]}"`
    print `cobbler system edit --name #{server_name} --interface bmc --dns-name=#{server_name}.bmc.#{config["MGTDOMAIN"]} --ip-address=#{config["IPBMC"]}`
    print `cobbler system edit --name #{server_name} --in-place --ksmeta "ipmiset=true ipminetmask='#{config["MGTNETMASK"]}' ipmigateway='#{config["GWMGT"]}' ipmilanchannel=1 ipmiuserid=2"`
  end


  # Setup of infiniband adapter is available
  if ! config["IB_INT"] == nil
    print `cobbler system edit --name #{server_name} --interface #{config["IB_INT"]} --dns-name=#{server_name}.#{config["IBDOMAIN"]} --ip-address=#{config["IPIB"]} --netmask=#{config["IBNETMASK"]} --static=true`
  end

end