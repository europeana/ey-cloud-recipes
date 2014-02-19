#
# Cookbook Name:: solr
# Recipe:: default
#

if (node[:solr_utility_name].empty? && ['solo', 'util'].include?(node[:instance_role])) ||
  (!node[:solr_utility_name].empty? && (node[:name] == node[:solr_utility_name]))
  
  solr_version = node[:solr_version]
  solr_file = "apache-solr-#{solr_version}.tgz"
  solr_dir = "apache-solr-#{solr_version}"
  solr_url = "http://archive.apache.org/dist/lucene/solr/#{solr_version}/#{solr_file}"
  solr_applications = node[:applications].select { |app_name, data| File.directory?("/data/#{app_name}/current/solr/conf") }
  
  directory "/var/run/solr" do
    action :create
    owner node[:owner_name]
    group node[:owner_name]
    mode 0755
  end

  directory "/var/log/engineyard/solr" do
    action :create
    owner node[:owner_name]
    group node[:owner_name]
    mode 0755
    recursive true
  end

  template "/etc/monit.d/solr.monitrc" do
    source "solr.monitrc.erb"
    owner node[:owner_name]
    group node[:owner_name]
    mode 0644
    variables({
      :user => node[:owner_name],
      :group => node[:owner_name],
      :memory_limit => node[:solr_memory_limit]
    })
  end
  
  directory "/data/solr" do
    action :create
    owner node[:owner_name]
    group node[:owner_name]
    mode 0755
  end

  remote_file "/data/#{solr_file}" do
    source "#{solr_url}"
    owner node[:owner_name]
    group node[:owner_name]
    mode 0644
    backup 0
    not_if { FileTest.exists?("/data/#{solr_file}") }
  end

  execute "unarchive solr-to-install" do
    command "cd /data && tar zxf #{solr_file} && sync"
    not_if { FileTest.directory?("/data/#{solr_dir}") }
  end
  
  execute "initialize from solr example package" do
    command "cd /data/#{solr_dir}/example && cp -r etc lib start.jar webapps work /data/solr"
    not_if { FileTest.exists?("/data/solr/start.jar") }
  end
  
  execute "chown_solr" do
    command "chown #{node[:owner_name]}:#{node[:owner_name]} -R /data/solr"
  end
  
  directory "/data/solr/multicore" do
    action :create
    owner node[:owner_name]
    group node[:owner_name]
    mode 0755
  end
  
  template "/data/solr/multicore/solr.xml" do
    source "solr.xml.erb"
    owner node[:owner_name]
    group node[:owner_name]
    mode 0644
    variables({
      :applications => solr_applications
    })
  end
  
  solr_applications.each do |app_name, data|
    app_solr_conf_dir = "/data/#{app_name}/current/solr/conf"
    directory "/data/solr/multicore/#{app_name}" do
      action :create
      owner node[:owner_name]
      group node[:owner_name]
      mode 0755
    end
    
    execute "link to #{app_name} solr config" do
      command "ln -nfs #{app_solr_conf_dir} /data/solr/multicore/#{app_name}/conf"
    end
  end

  template "/engineyard/bin/solr" do
    source "solr.erb"
    owner node[:owner_name]
    group node[:owner_name]
    mode 0755
    variables({
      :rails_env => node[:environment][:framework_env],
      :memory_limit => node[:solr_memory_limit]
    })
  end

  execute "monit-reload" do
    command "monit quit && telinit q"
  end

  execute "start-solr" do
    command "sleep 3 && monit start solr"
  end
end

if node[:solr_sunspot]
  include_recipe "solr::sunspot"
end
