################################################################################
##
## Alces HPC Software Stack - Puppet configuration files
## Copyright (c) 2008-2013 Alces Software Ltd
##
################################################################################
class symphony
{
  class { 'symphony::nfs':
    nfsimports => hiera('symphony::nfsimports',undef),
  }
}
