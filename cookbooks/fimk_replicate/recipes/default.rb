#
# Cookbook Name:: fimk
# Recipe:: default
#
# Copyright 2016, Krypto Fin ri
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'apt::default'

user "fimk_replicate" do
  supports  :manage_home => true
  comment   "FIMK Replicate User"
  uid       2341
  gid       "users"
  home      "/home/fimk_replicate"
  shell     "/bin/bash"
end

mysql2_chef_gem 'default' do
  action :install
end

# Configure the MySQL client.
mysql_client 'default' do
  version node[:fimk_replicate][:mysql_version]
  action :create
end

mysql_service 'default' do
  version node[:fimk_replicate][:mysql_version]
  initial_root_password node[:fimk_replicate][:root_password]
  action [:create, :start]
end

# Create the database instance.
mysql_database node[:fimk_replicate][:database_name] do
  connection(
    :host => '127.0.0.1',
    :username => 'root',
    :password => node[:fimk_replicate][:root_password]
  )
  action :create
end

# Add a database user.
mysql_database_user node[:fimk_replicate][:db_user_name] do
  connection(
    :host => '127.0.0.1',
    :username => 'root',
    :password => node[:fimk_replicate][:root_password]
  )
  password node[:fimk_replicate][:db_user_pwd]
  database_name node[:fimk_replicate][:database_name]
  host '127.0.0.1'
  action [:create, :grant]
end
