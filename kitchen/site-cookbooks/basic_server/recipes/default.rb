node[:packages].each do |pkg|
  package pkg do
    action :install
  end
end

[node[:users], node[:site_users]].each do |users_node|
  users_node.each do |username|
    user username do
      user_data_bag = Chef::EncryptedDataBagItem.load('users', username)
      password user_data_bag[:password]
      home "/home/#{username}"
      shell '/bin/bash'
      supports :manage_home => true
    end

    # Configure /home/username .profile and .bashrc
    ['profile', 'bashrc'].each do |bash_script|

      # Main Chef-managed shell script
      template "/home/#{username}/.#{bash_script}" do
        source "users/#{bash_script}.erb"
        owner username
        group username
        mode 0644
      end

      # Additional shell scripts
      directory "/home/#{username}/.#{bash_script}.d" do
        owner username
        group username
        mode 0755
      end

      # User-customizable shell script
      template "/home/#{username}/.#{bash_script}.d/user.sh" do
        source "users/#{bash_script}.d/user.sh.erb"
        owner username
        group username
        mode 0644
        not_if { File.exists?("/home/#{username}/.#{bash_script}/user.sh") }
      end

      # Additional Chef-managed shell scripts
      directory "/home/#{username}/.#{bash_script}.d/chef" do
        owner username
        group username
        mode 0755
      end

      # pid directory
      directory "/home/#{username}/pids"

    end
  end unless users_node.nil?
end

# Create groups idempotently. The chef user should be in every group.
[node[:groups], node[:site_groups]].each do |groups_node|
  groups_node.each do |group_name, group_config|
    group group_name do
      action :create
      members ['chef']
      not_if "grep #{group_name} /etc/group"
    end
  end unless groups_node.nil?

  groups_node.each do |group_name, group_config|
    group group_name do
      action :manage
      members group_config[:members]
      append true
    end
  end unless groups_node.nil?
end
# Add logrotate entry to cron.hourly in addition to the default cron.daily

# Main Chef-managed shell script
template "/etc/cron.hourly/logrotate" do
  source "cron.hourly/logrotate.erb"
  mode 0755
end