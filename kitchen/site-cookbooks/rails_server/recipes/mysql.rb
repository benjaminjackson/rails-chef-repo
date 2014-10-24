## Mysql

user 'mysql' do
  system true
end

gem_package 'mysql' do
  action :install
end

mysql_data_bag = Chef::EncryptedDataBagItem.load('mysql_root_users', node[:mysql_root_user_databag])

# For some reason all of these have to be set
node.set['mysql']['server_root_password'] = mysql_data_bag[:password]
node.set['mysql']['server_debian_password'] = mysql_data_bag[:password]
node.set['mysql']['server_repl_password'] = mysql_data_bag[:password]

node.set['mysql']['server']['slow_query_log_file']  = '/var/log/mysql/mysql-slow.log'

node['databases'].each do |db_id, db|
  db_data_bag = Chef::EncryptedDataBagItem.load('databases', db_id)
  node.set['databases'][db_id]['password'] = db_data_bag[:password]
end

template '/etc/mysql/conf.d/default.cnf' do
  owner 'mysql'
  owner 'mysql'      
  source 'mysql/conf.d/default.cnf.erb'
end

include_recipe "mysql::server"