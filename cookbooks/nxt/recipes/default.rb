#
# Cookbook Name:: nxt
# Recipe:: default
#
# Copyright 2014, Krypto Fin ri
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'apt::default'

user "nxt" do
  supports  :manage_home => true
  comment   "NXT User"
  uid       5432
  gid       "users"
  home      "/home/nxt"
  shell     "/bin/bash"
end

apt_package "unzip" do
  action :install
end

apt_package "zip" do
  action :install
end

apt_package "curl" do
  action :install
end

apt_package "python-software-properties" do
  action :install
end

apt_package "software-properties-common" do
  action :install
end

execute "addding ppa:webupd8team/java" do
  command "add-apt-repository ppa:webupd8team/java"
  action :run
  returns [0,1]
end

execute "addding ppa:brightbox/ruby-ng" do
  command "apt-add-repository ppa:brightbox/ruby-ng"
  action :run
  returns [0,1]
end

execute "update package index" do
  command "apt-get update"
  action :run
end

execute "accept oracle license" do
  command "echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections"
  action :run
end

apt_package "oracle-java8-installer" do
  action :install
end

apt_package "ruby2.1" do
  action :install
end

apt_package "ruby2.1-dev" do
  action :install
end

apt_package "linux-headers-generic" do
  action :install
end

apt_package "build-essential" do
  action :install
end 

cookbook_file "/home/nxt/nxt.zip" do
  source "nxt.zip"
  mode 00644
end

bash "install_nxt" do
  user "nxt"
  cwd  "/home/nxt"
  code "unzip -o nxt.zip -d nxt/"
end

template "/home/nxt/nxt/conf/nxt.properties" do
  source    "nxt.properties.erb"
  mode      00644
  owner     "nxt"
  variables :properties => node[:nxt][:properties]
end

template "/home/nxt/nxt/conf/logging.properties" do
  source    "logging.properties.erb"
  mode      00644
  owner     "nxt"
  variables :properties => node[:nxt][:logging]
end

template "/etc/init/nxt.conf" do
  source    "nxt.conf.erb"
  mode      00644
  owner     "root"
  group     "root"
  variables :from           => "#{node['ipaddress']}@nxt-cluster.fi",
            :to             => 'incentivetoken@gmail.com',
            :log_file       => '/home/nxt/nxt/logs/nxt.log'
end

service "nxt" do
  provider Chef::Provider::Service::Upstart
  supports :restart => true, :start => true, :stop => true
end

service "nxt" do
  action [:enable, :start]
end

if node[:ssmtp] then
  apt_package "ssmtp" do
    action :install
  end

  gem_package "tlsmail" do
    action :install
  end

  template "/etc/ssmtp/ssmtp.conf" do
    source    "ssmtp.conf.erb"
    mode      00644
    owner     "root"
    group     "root"
    variables :properties => node[:ssmtp]
  end
end

if ['hourly','daily','weekly'].include? node[:nxt][:properties][:backup] then
  template "/etc/cron.#{node[:nxt][:properties][:backup]}/nxt_backup" do
    source    "nxt_backup.sh.erb"
    mode      '0755'
    owner     "root"
    group     "root"
    variables :properties => node[:nxt][:properties]
  end
end