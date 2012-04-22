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

#
# puppet-specific bootstrapping
#

# install puppet packages and gems
apt-get install puppet rubygems -yq
# update rubygems to latest
sudo gem install rubygems-update && update_rubygems
gem install puppet-module hiera hiera-json hiera-puppet foreman

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
