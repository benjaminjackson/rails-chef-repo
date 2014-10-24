# Set rails shell configuration on all app users who have a home directory

node[:groups]["app"][:members].each do |username|
  template "/home/#{username}/.profile.d/chef/rails_app.sh" do
    source 'profile.d/rails_app.sh.erb'
    owner username
    group username
    mode 0644
    only_if { ::File.exists?("/home/#{username}/") }
  end
end

# Individual databases

database_connection_info = {
  :host => 'localhost',
  :username => 'root',
  :password => node[:mysql][:server_root_password]
}

node[:databases].each do |db_id, db|
  mysql_database db[:name] do
    connection database_connection_info
    encoding 'utf8'
    action :create
  end

  mysql_database_user db[:username] do
    connection database_connection_info
    password db[:password]
    database_name db[:name]
    action :grant
  end
end

mysql_database "flush privileges" do
  connection database_connection_info
  sql "flush privileges"
  action :query
end

# Create app path

directory node[:app_config][:app_path] do
  recursive true
  owner "app"
  group "app"
  mode 0775
end

# /home/app/www/app gets created recursively, and unfortunately
# chef always sets intermediate directories to root, so we need
# to fix that here

execute "fix ownership of #{node[:app_config][:app_path]}" do
  command "chown -R app:app #{node[:app_config][:app_path]}"
  only_if { Etc.getpwuid(File.stat("#{node[:app_config][:app_path]}/..").uid).name != "app" }
end

# Nginx config

directory node[:app_config][:nginx][:log_path] do
  owner "www-data"
  group "adm"
  mode 0775
end

execute "fix permissions of #{node[:app_config][:nginx][:log_path]}" do
  command "chmod 775 #{node[:app_config][:nginx][:log_path]}"
end

['/etc/nginx/htpasswd', '/etc/nginx/ssl_keys'].each do |d|
  directory d do
    owner "www-data"
    group "www-data"
    mode 0775
  end

  execute "fix permissions of #{d}" do
    command "chmod 775 #{d}"
  end
end

if node[:app_config][:nginx] && node[:app_config][:nginx][:htpasswd].size > 0
  template "/etc/nginx/htpasswd/#{node[:app_config][:name]}.conf" do
    source 'htpasswd.conf.erb'
    owner 'www-data'
    group 'www-data'
    mode 0775
  end
end

node.set['app_config']['nginx']['hosts']['all'] = [
  node[:app_config][:nginx][:host][:default],
  node[:app_config][:nginx][:host][:public],
  node[:app_config][:nginx][:host][:internal],
  node[:app_config][:nginx][:host][:aliases]
].flatten.uniq.reject { |h| h.to_s.empty? }.join(" ")

template "/etc/nginx/sites-available/#{node[:app_config][:name]}.conf" do
  source 'nginx/app.conf.erb'
  owner 'www-data'
  group 'www-data'
  mode 0775
end

sites_to_enable = ["#{node[:app_config][:name]}.conf"]

if node[:app_config][:nginx][:ssl]

  certificate = Chef::EncryptedDataBagItem.load('certificates', node[:app_config][:nginx][:ssl_certificate])

  template "/etc/nginx/ssl_keys/#{node[:app_config][:nginx][:ssl_certificate]}.key" do
    source "nginx/ssl_certificate.key.erb"
    variables({
      "contents" => certificate[:key].join("\n")
    })
    owner 'www-data'
    group 'www-data'
    mode 0775
  end

  template "/etc/nginx/ssl_keys/#{node[:app_config][:nginx][:ssl_certificate]}.pem" do
    source "nginx/ssl_certificate.pem.erb"
    variables({
      "contents" => certificate[:pem].join("\n")
    })
    owner 'www-data'
    group 'www-data'
    mode 0775
  end

  template "/etc/nginx/sites-available/#{node[:app_config][:name]}-ssl.conf" do
    source 'nginx/app-ssl.conf.erb'
    owner 'www-data'
    group 'www-data'
    mode 0664
  end

  sites_to_enable << "#{node[:app_config][:name]}-ssl.conf"
end

# Enable (or restart) nginx

sites_to_enable.each do |site_conf|
  nginx_site site_conf do
    enable true
  end
end

# Logrotate for the rails app

logrotate_app 'rails_app' do
  cookbook 'logrotate'
  path "#{node[:app_config][:app_path]}/log/*.log"
  frequency 'daily'
  rotate 7
  size '512M'
  create '664 app app'
  options ['missingok', 'compress', 'delaycompress', 'copytruncate']
  sharedscripts true
  postrotate "god restart rails; god restart resque"
end

# God config

god_monitor "rails_app" do
  config "rails_app.god.erb"
end
