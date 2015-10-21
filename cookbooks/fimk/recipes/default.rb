#
# Cookbook Name:: fimk
# Recipe:: default
#
# Copyright 2014, Krypto Fin ri
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'apt::default'

user "fim" do
  supports  :manage_home => true
  comment   "FIM User"
  uid       2345
  gid       "users"
  home      "/home/fim"
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

cookbook_file "/home/fim/fim.zip" do
  source "fim.zip"
  mode 00644
end

bash "install_fim" do
  user "fim"
  cwd  "/home/fim"
  code "unzip -o fim.zip -d fim/"
end

template "/home/fim/fim/conf/nxt.properties" do
  source    "nxt.properties.erb"
  mode      00644
  owner     "fim"
  variables :properties => node[:fimk][:properties]
end

template "/home/fim/fim/conf/logging.properties" do
  source    "logging.properties.erb"
  mode      00644
  owner     "fim"
  variables :properties => node[:fimk][:logging]
end

template "/etc/init/fimk.conf" do
  source    "fimk.conf.erb"
  mode      00644
  owner     "root"
  group     "root"
  variables :from           => "#{node['ipaddress']}@fimk-cluster.fi",
            :to             => 'incentivetoken@gmail.com',
            :log_file       => '/home/fim/fim/logs/fim.log'
end

service "fimk" do
  provider Chef::Provider::Service::Upstart
  supports :restart => true, :start => true, :stop => true
end

service "fimk" do
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

template "/etc/cron.daily/fimk_backup" do
#template "/etc/cron.hourly/fimk_backup" do
  source    "fimk_backup.sh.erb"
  mode      '0755'
  owner     "root"
  group     "root"
  variables :properties => node[:fimk][:properties]
end

# cron 'backup_blockchain' do
#   action :create
#   # hour '1' # everyday at 1
#   hour '*/1' # every hour
#   # minute '*/1' # every minute
#   user 'fim'
#   command 'sh /home/fim/fimk_backup.sh'
# end