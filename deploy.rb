# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'fileutils'
require 'optparse'
require 'json'

options={}
config={}
current_dir=File.dirname(__FILE__)
files_dir= {
  'fimk' => File.expand_path(File.join(current_dir, 'cookbooks/fimk/files/default')),
  'fimk_test' => File.expand_path(File.join(current_dir, 'cookbooks/fimk_test/files/default')),
  'nxt' => File.expand_path(File.join(current_dir, 'cookbooks/nxt/files/default')),
  'fimk_webapp' => File.expand_path(File.join(current_dir, 'cookbooks/fimk_webapp/files/default'))
}
app_dir={
  'fimk' => '/home/fim/fim',
  'nxt' => '/home/nxt/nxt'
}

OptionParser.new do |opts|
  opts.banner = "Usage: deploy.rb [options]"
  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
  opts.on("-n", "--nodes X,Y,Z", Array, "Override list of nodes'") do |nodes|
    options[:nodes] = nodes
  end
  opts.on("-r", "--run-list fimk,fimk_test,nxt,fimk_webapp,fimk_replicate", Array, "Override runlist (allowed are 'fimk','fimk_test','nxt','fimk_webapp','fimk_replicate')") do |run_list|
    options[:run_list] = run_list
  end
  opts.on("-u","--user [ROOT]", "SSH user") do |user|
    options[:user] = user
  end
  opts.on("-p","--force-prepare", "Force run 'knife solo prepare'") do |prepare|
    options[:prepare] = prepare
  end
  opts.on("-i","--identity [FILE]", "SSH identity file") do |identity|
    options[:identity] = identity
  end
  opts.on("-f","--config-file [FILE]", "Config file") do |config_file|
    options[:config_file] = config_file
  end
  opts.on("-s","--source-dir [DIR]", "Source tree") do |source_dir|
    options[:source_dir] = source_dir
  end
  opts.on("-z","--zip-file [FILE]", "Distribution as zip file") do |zip_file|
    options[:zip_file] = zip_file
  end
  opts.on("-j","--java-bin [FILE]", "Java binary") do |java_bin|
    options[:java_bin] = java_bin
  end
  opts.on("-c","--compile", "Compile source code") do |compile|
    options[:compile] = compile
  end
end.parse!

if options.include?(:config_file) then
  config_file = options[:config_file]
else
  config_file = File.join(current_dir, 'config.json')
end

abort("Missing or non-existing --config-file or config.json") unless File.exist?(config_file)
config=File.open(config_file, "r" ) do |f| JSON.load(f) end

define_method(:trace) do |msg|
  puts msg # if options[:verbose]
end

define_method(:exec) do |dir, cmd|
  puts("Executing Command: '#{cmd}' in dir '#{dir}'") if options[:verbose]
  Dir.chdir(dir) { system cmd }
end

define_method(:exec_ssh) do |host, user, cmd, port, identity=nil|
  script  = "ssh "
  #script += "-v " if options[:verbose]
  script += "#{host} "
  script += "-i #{identity} " if identity
  script += "-l #{user} "
  script += "-p #{port} "
  script += "-C '#{cmd}' "
  exec(current_dir, script)
end

class ::Hash
  def deep_merge(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge(second, &merger)
  end
end

is_compiled={}
define_method(:compile) do |engine, source_dir|
  is_compiled[engine] = is_compiled[engine]||{}
  return if is_compiled[engine].include?(source_dir)
  is_compiled[engine][source_dir] = 1

  java_bin = options[:java_bin]||config['java_bin']||File.join(ENV['HOME'], 'jdk1.8.0', 'bin')

  puts "Compiling #{engine} from source #{source_dir}"
  exec(source_dir, "export PATH=$PATH:#{java_bin} && sh compile_with_keystore.sh")
  puts "Compilation succeeded"

  file_name = (engine=='fimk'||engine=='fimk_test') ? 'fim.zip' : 'nxt.zip'
  exec(files_dir[engine], "rm -f #{file_name}")
  exec(source_dir, "mv -f -u #{file_name} #{files_dir[engine]}")
end

define_method(:chef_conf_file) do |host|
  File.expand_path(File.join(current_dir, "nodes/#{host}.json"))
end

define_method(:chef_conf) do |host, run_list, attributes|
  base = {
    "run_list" => run_list,
    "automatic" => {
      "ipaddress" => host
    }
  }
  attributes.each do |name, value|
    base[name] = value
  end
  File.open(chef_conf_file(host),"w") do |f|
    f.write(JSON.pretty_generate(base))
  end
end

define_method(:package_webapp) do
  target_dir = File.expand_path(File.join(current_dir, 'cookbooks/fimk_webapp/files/default'))
  source_dir = config['source_dir']['fimk_webapp']
  exec(source_dir, 'sh compress.sh')
  exec(files_dir['fimk_webapp'], "rm -f app.js")
  file_name = config['zip_file']['fimk_webapp']
  exec(source_dir, "mv -f -u #{file_name} #{files_dir['fimk_webapp']}")
end

# Determine on what nodes we are operating.
# Either process all nodes in config file or limit to --nodes if argument was provided
nodes = options[:nodes]||config['nodes'].select { |k,node| !node.include?('exclude') }.keys

puts "Deploy will be run on #{nodes.to_s}"
puts "Click ENTER to continue"
gets

# Provision each node individually
nodes.each do |host|
  conf=config['nodes'][host]
  identity=options[:identity]||conf['identity']
  user=options[:user]||conf['user']||config['user']
  port=conf['port']||22
  run_list=options[:run_list]||conf['run_list']||config['run_list']||[]

  trace("Deploying #{run_list} on #{host}")

  # exec(current_dir, "ssh-keygen -R #{host}")

  # Process all recipes/roles
  run_list.each do |entry|
    supported = ['nxt','fimk','fimk_test','role[webserver]','fimk_webapp','fimk_replicate']
    abort("Unsupported run_list argument (supported: #{supported})") unless supported.include?(entry)

    if ['nxt','fimk','fimk_test'].include? entry then
      puts "Deploying #{entry}"
      # Do we compile or use the zip?
      if options[:compile] then
        source_dir = options[:source_dir]||config['source_dir'][entry]
        trace("Compiling from source --source-dir=#{source_dir}")
        abort("#{entry} source-dir does not exist") unless File.exist?(source_dir)
        compile(entry, source_dir)
      else
        zip_file = options[:zip_file]||config['zip_file'][entry]
        abort("#{entry} zip-file does not exist") unless File.exist?(zip_file)
        trace("Deploying from zip file --zip-file=#{zip_file}")
        file_name = File.basename(zip_file)
        abort("--zip-file name must be fim.zip or nxt.zip") unless ['nxt.zip','fim.zip'].include?(file_name)
        exec(files_dir[entry], "rm -f #{file_name}")
        exec(current_dir, "cp -u #{zip_file} #{files_dir[entry]}")
      end
    end
    if 'role[webserver]'==entry then
      puts "Deploying webserver"
    end
    if 'fimk_replicate'==entry then
      puts "Deploying FIMK replicate"
    end
    if 'fimk_webapp'==entry then
      puts "Deploying FIMK webapp"
      package_webapp
    end
  end

  # optional knife solo ssh arguments
  # -i identityfile
  # -P password
  # -p port
  if options[:prepare] || (not File.exist? chef_conf_file(host)) then
    exec(current_dir, "bundle exec knife solo prepare #{user}@#{host} -p #{port}")
  end

  run_list.each do |entry|
    if ['nxt','fimk','fimk_test'].include? entry then
      exec_ssh(host, user, "stop #{entry}", port)
      exec_ssh(host, user, "rm #{app_dir[entry]}/conf/nxt.properties", port)
    end
    if ['fimk_webapp'].include? entry then
      exec_ssh(host, user, "stop fimk_webapp", port)
    end
  end

  chef_conf(host, run_list, (conf['attributes']||{}).deep_merge(config['attributes']||{}))
  exec(current_dir, "bundle exec knife solo cook #{user}@#{host} -p #{port}")

  run_list.each do |entry|
    if ['nxt','fimk','fimk_test'].include? entry then
      exec_ssh(host, user, "start #{entry}", port)
    end
    if ['fimk_webapp'].include? entry then
      exec_ssh(host, user, "start fimk_webapp", port)
    end
  end
end

# exec(current_dir, "ssh-keygen -R #{host}")
# To remove a host from known_hosts
# ssh-keygen -R 95.85.7.91