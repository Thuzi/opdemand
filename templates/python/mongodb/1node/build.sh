#!/bin/sh

# OpDemand bootstrap script for Puppet-managed servers
# This script runs as "root" on first boot typically
# invoked by cloud-init's runcmd.

# source orchestration inputs as environment vars
. /var/cache/opdemand/inputs.sh

# set locale for calls that require encoding
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# prevent dpkg prompting
export DEBIAN_FRONTEND=noninteractive

# install and update rubygems
apt-get install rubygems -yq
gem install rubygems-update && update_rubygems

# install required system gems
gem install foreman

#
# puppet-specific bootstrapping
#

# install puppet modules
gem install puppet hiera hiera-json hiera-puppet 

# install hiera config file
cat > /etc/puppet/hiera.yaml <<EOF
---
:backends: - json
           - puppet

:logger: console

:hierarchy: - inputs

:json:
   :datadir: /var/cache/opdemand

:puppet:
   :datasource: data
EOF

# clone puppet repository and checkout specified revision
mkdir -p $puppet_repository_path
git clone --recursive $puppet_repository_url $puppet_repository_path
cd $puppet_repository_path && git checkout -f $puppet_repository_revision

