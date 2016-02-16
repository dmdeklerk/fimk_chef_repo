#
# Cookbook Name:: fimk
# Recipe:: default
#
# Copyright 2016, Krypto Fin ri
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'apt::default'

user "fimk_webapp" do
  supports  :manage_home => true
  comment   "FIMK Webapp User"
  uid       2349
  gid       "users"
  home      "/home/fimk_webapp"
  shell     "/bin/bash"
end

if node[:platform].include?("ubuntu")
  bash "chris-lea-ppa" do
    user "root"
    code "sudo add-apt-repository ppa:chris-lea/node.js"
  end

  execute "update package index" do
    command "apt-get update"
    action :run
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

  apt_package "nodejs" do
    action :install
  end
end

cookbook_file "/home/fimk_webapp/app.zip" do
  source "app.zip"
  mode 00644
end

bash "install_webapp" do
  user "fimk_webapp"
  cwd  "/home/fimk_webapp"
  code "unzip -o app.zip -d fimk_webapp/"
end

bash "npm_install" do
  user "root"
  cwd  "/home/fimk_webapp/fimk_webapp"
  code "npm install"
end

if node[:platform].include?("ubuntu")
  template "/etc/init/fimk_webapp.conf" do
    source    "fimk_webapp.conf.erb"
    mode      00644
    owner     "root"
    group     "root"
    variables :from             => "#{node['ipaddress']}@fimk-webapp.fi",
              :to               => 'incentivetoken@gmail.com',
              :fimk_url         => node['fimk_webapp']['fimk_url'],
              :fimk_port        => node['fimk_webapp']['fimk_port'],
              :fimk_secret      => node['fimk_webapp']['fimk_secret'],
              :verification_url => node['fimk_webapp']['verification_url'],
              :is_testnet       => node['fimk_webapp']['is_testnet'],
              :recaptcha        => node['fimk_webapp']['recaptcha'],
              :database_url     => node['fimk_webapp']['database_url'],
              :node_bin         => '/usr/bin/nodejs'
  end

  service "fimk_webapp" do
    provider  Chef::Provider::Service::Upstart
    supports  :restart => true, :start => true, :stop => true
  end

  service "fimk_webapp" do
    action    [:enable, :start]
  end

  if node[:ssmtp] then
    apt_package "ssmtp" do
      action  :install
    end

    gem_package "tlsmail" do
      action  :install
    end

    template "/etc/ssmtp/ssmtp.conf" do
      source    "ssmtp.conf.erb"
      mode      00644
      owner     "root"
      group     "root"
      variables :properties => node[:ssmtp]
    end
  end
end
if node[:platform].include?("centos")
  template "/etc/init/fimk_webapp.conf" do
    source    "fimk_webapp.conf.erb"
    mode      00644
    owner     "root"
    group     "root"
    variables :from             => "#{node['ipaddress']}@fimk-webapp.fi",
              :to               => 'incentivetoken@gmail.com',
              :fimk_url         => node['fimk_webapp']['fimk_url'],
              :fimk_port        => node['fimk_webapp']['fimk_port'],
              :fimk_secret      => node['fimk_webapp']['fimk_secret'],
              :verification_url => node['fimk_webapp']['verification_url'],
              :is_testnet       => node['fimk_webapp']['is_testnet'],
              :recaptcha        => node['fimk_webapp']['recaptcha'],
              :database_url     => node['fimk_webapp']['database_url'],
              :cert_file        => node['fimk_webapp']['cert_file'],
              :key_file         => node['fimk_webapp']['key_file'],
              :node_bin         => '/usr/bin/node'
  end

  service "fimk_webapp" do
    provider  Chef::Provider::Service::Upstart
    supports  :restart => true, :start => true, :stop => true
  end

  service "fimk_webapp" do
    action    [:enable, :start]
  end
end