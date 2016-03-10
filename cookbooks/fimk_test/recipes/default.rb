#
# Cookbook Name:: fimk
# Recipe:: default
#
# Copyright 2014, Krypto Fin ri
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'apt::default'

user "fimk_test" do
  supports  :manage_home => true
  comment   "FIM TEST User"
  uid       2369
  gid       "users"
  home      "/home/fimk_test"
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

# execute "update package index" do
#   command "sudo apt-get update"
#   action :run
# end

execute "apt-get-update" do
  command "apt-get update"
  ignore_failure true
  action :nothing
end

package "update-notifier-common" do
  notifies :run, resources(:execute => "apt-get-update"), :immediately
end

execute "apt-get-update-periodic" do
  command "apt-get update"
  ignore_failure true
  only_if do
   File.exists?('/var/lib/apt/periodic/update-success-stamp') &&
   File.mtime('/var/lib/apt/periodic/update-success-stamp') < Time.now - 86400
  end
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

cookbook_file "/home/fimk_test/fim.zip" do
  source "fim.zip"
  mode 00644
end

bash "install_fim" do
  user "fimk_test"
  cwd  "/home/fimk_test"
  code "unzip -o fim.zip -d fim/"
end

bash "rename_jar" do
  user "fimk_test"
  cwd  "/home/fimk_test/fim"
  code "mv fim.jar fimk_test.jar"
end

template "/home/fimk_test/fim/conf/nxt.properties" do
  source    "nxt.properties.erb"
  mode      00644
  owner     "fimk_test"
  variables :properties => node[:fimk_test][:properties]
end

template "/home/fimk_test/fim/conf/logging.properties" do
  source    "logging.properties.erb"
  mode      00644
  owner     "fimk_test"
  variables :properties => node[:fimk_test][:logging]
end

template "/etc/init/fimk_test.conf" do
  source    "fimk_test.conf.erb"
  mode      00644
  owner     "root"
  group     "root"
  variables :from           => "#{node['ipaddress']}@fimk_test-cluster.fi",
            :to             => 'incentivetoken@gmail.com',
            :log_file       => '/home/fimk_test/fim/logs/fim.log'
end

service "fimk_test" do
  provider Chef::Provider::Service::Upstart
  supports :restart => true, :start => true, :stop => true
end

service "fimk_test" do
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

if ['hourly','daily','weekly'].include? node[:fimk_test][:properties][:backup] then
  template "/etc/cron.#{node[:fimk_test][:properties][:backup]}/fimk_test_backup" do
    source    "fimk_test_backup.sh.erb"
    mode      '0755'
    owner     "root"
    group     "root"
    variables :properties => node[:fimk_test][:properties]
  end
end