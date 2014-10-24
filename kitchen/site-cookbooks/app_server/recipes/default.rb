
# God config

include_recipe "god"

begin
  t = resources(:template => "/etc/god/master.god")
  t.source "master.god.erb"
  t.cookbook "app_server"
rescue Chef::Exceptions::ResourceNotFound
  Chef::Log.warn "could not find template /etc/god/master.god to modify"
end

sudo 'god' do
  group      "app"
  commands  [ "/usr/bin/god stop *",
              "/usr/bin/god start *",
              "/usr/bin/god restart *",
              "/usr/bin/god status *",
              "/usr/bin/god load *",
              "/usr/bin/god remove *",
              "/usr/bin/god unmonitor *",
              "/usr/bin/god quit",
              "/usr/bin/god"
            ]
  nopasswd  true
end

# Github

execute "initialize connection to github" do
#  user    "app"
  command "ssh -o StrictHostKeychecking=no git@github.com; true"
end

# Override Nginx logrotate to include apps

template "/etc/logrotate.d/nginx" do
  source "nginx_logrotate.erb"
  owner 'root'
  group 'root'
  mode 0744
end