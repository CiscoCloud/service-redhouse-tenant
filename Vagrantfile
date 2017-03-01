# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'
require 'fileutils'

$data = {:user => 'vagrant', :group => 'vagrant'}
host_entries = [
  '192.168.100.6 dev-int dev-int.cis.local',
  '192.168.100.5 dev dev.cis.local',
  '192.168.100.4 dev-storage dev-storage.cis.local',
  '192.168.100.20 dev-aio.cis.local'
]

# Load settings
$default_settings = YAML::load_file('.default_settings.yaml')
if File.exists?('settings.yaml')
  $user_settings = YAML::load_file('settings.yaml')
  $settings = $default_settings.merge($user_settings)
else
  $settings = $default_settings
end

# Load environment config
$envyaml = YAML::load_file('./vagrant.yaml')
$envyaml['hosts'].each do |name, h|
  host_entries << "#{h['ip']} #{name} #{name}.cis.local"
end
File.open(".ccs_vagrant_hosts", "w") {|f| f.write(host_entries.join("\n")) }

# Global provision script
$setup_script = <<SCRIPT
echo "export CCS_ENVIRONMENT=dev-tenant" >> /root/.bashrc
echo "export CCS_ENVIRONMENT=dev-tenant" >> /home/vagrant/.bashrc
if [ -d /home/cloud-user ]; then
    echo "export CCS_ENVIRONMENT=dev-tenant" >> /home/cloud-user/.bashrc
fi
echo "localhost ansible_connection=local" > /etc/ansible/hosts
sed -i 's/\s//g' /etc/puppet/puppet.conf
sed -r -i 's/search.*/search cis.local/g' /etc/resolv.conf
SCRIPT

$provision_script = <<SCRIPT
[ -L /opt/ccs/services/redhouse-tenant/data/site.yaml ] || \
  ln -s /etc/puppet/data/hiera_data/site.yaml /opt/ccs/services/redhouse-tenant/data/site.yaml
# short term hack since dependency mapping isn't really all there
yum -y install python-oslo-serialization python-oslo-utils
cd /opt/ccs/services/redhouse-tenant/puppet
puppet apply -v --show_diff --confdir . manifests/site.pp
puppet apply -v --show_diff --confdir . -e 'include openstack::auth_file'
SCRIPT

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  $envyaml['hosts'].each do |name, ho|
    config.vm.define name.split('.')[0] do |h|
      if ho['box']
        h.vm.box = ho['box']
      else
        h.vm.box = "precise64_puppet"
        h.vm.box_url = "http://puppet-vagrant-boxes.puppetlabs.com/ubuntu-server-12042-x64-vbox4210.box"
      end

      h.vm.network "private_network", ip: ho['ip'], mac: ho['mac']
      h.vm.host_name = "#{name}.cis.local"

      # Synced folders
      h.vm.synced_folder ".", "/vagrant", disabled: true
      h.vm.synced_folder "dev/ccs-data/out/ccs-dev-1/dev-tenant/etc/ccs/data/", "/etc/ccs/data/environments/dev-tenant"
      h.vm.synced_folder "dev/ccs-data/out/ccs-dev-1/dev-tenant/etc/puppet/data/hiera_data", "/etc/puppet/data/hiera_data"
      h.vm.synced_folder ".", "/opt/ccs/services/redhouse-tenant"
      # Synced folders for local repository mirror
      if File.directory?("mirror")
        h.vm.synced_folder "mirror", "/var/mirror"
      end
      if File.directory?("repo_mirror")
        h.vm.synced_folder "repo_mirror", "/var/www/cobbler/repo_mirror"
      end
      if File.directory?("user")
        h.vm.synced_folder "user", "/opt/user"
      end

      if ho['ports']
        ho['ports'].each do |port|
          h.vm.network "forwarded_port", guest: port['guest'], host: port['host']
        end
      end
      if $settings['openstack_provider'] == true
        # OpenStack Provider
        require 'vagrant-openstack-provider'
        config.ssh.username = 'cloud-user'
        h.vm.provider :openstack do |os, override|
          require 'vagrant-openstack-provider'
          os.openstack_auth_url        = "#{ENV['OS_AUTH_URL']}/tokens"
          os.username                  = ENV['OS_USERNAME']
          os.password                  = ENV['OS_PASSWORD']
          os.tenant_name               = ENV['OS_TENANT_NAME']
          os.flavor                    = $settings['flavor']
          os.image                     = $settings['image']
          os.floating_ip_pool          = $settings['floating_ip_pool']
          os.openstack_network_url     = $settings['os_network_url']
          os.openstack_image_url       = $settings['os_image_url']
          os.security_groups           = $settings['security_groups']
          os.networks                  = [{ name: $settings['mgmt_network']} ,{ name: $settings['lab_network'], address: ho['ip']}]
          override.vm.box = 'openstack'
        end
      else
        # Vagrant Provider
        h.vm.provider :virtualbox do |vb|
          if ho['memory']
            vb.customize ["modifyvm", :id, "--memory", ho['memory']]
          end
          vb.customize ["modifyvm", :id, "--usb", "off"]
          if ho['storage_disks']
            vb.customize ["storagectl", :id, "--name", "SATA Controller", "--add", "sata"]
            disk_port_num = 2
            ho['storage_disks'].each do |sd|
              disk_port_num += 1
              file_to_disk = "#{name}-disk-#{sd}"
              unless File.exist?(file_to_disk)
                vb.customize ['createhd', '--filename', file_to_disk, '--size', 102400]
              end
              vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', disk_port_num, '--device', 0, '--type', 'hdd', '--medium', file_to_disk + '.vdi']
            end
          end
        end
      end

      if $settings['cache_packages']
        if ! File.directory?('./user/cache')
          FileUtils::mkdir_p './user/cache'
        end
        h.vm.synced_folder "user/cache", "/var/cache/yum"
        h.vm.provision :shell, inline: "ansible localhost -m ini_file -a 'dest=/etc/yum.conf section=main option=keepcache value=1'"
      end
      h.vm.provision :shell, inline: "echo role=#{ho['role']} > /etc/facter/facts.d/role.txt"

      if $settings['openstack_provider'] == true
        h.vm.provision :shell, inline: "chown cloud-user:cloud-user /etc/puppet"
      else
        h.vm.provision :shell, inline: "chown vagrant:vagrant /etc/puppet"
      end
      h.vm.provision :shell, inline: "mkdir -p /var/lib/cobbler; chmod -R 777 /var/lib/cobbler"
      h.vm.provision :file, source: ".ccs_vagrant_hosts", destination: "/var/lib/cobbler/cobbler_hosts_additional"
      #Update hosts file
      h.vm.provision :shell, inline: "grep -q $(hostname -I | cut -f2 -d' ') /etc/hosts || cat /opt/ccs/services/redhouse-tenant/.ccs_vagrant_hosts >> /etc/hosts"

      if name != 'infra-001'
        h.vm.provision :shell, inline: $setup_script
        h.vm.provision :shell, inline: "ansible-playbook /opt/ccs/services/redhouse-tenant/dev/provision.yml -e 'hostname=#{name}.cis.local'"
        h.vm.provision :shell, inline: "sudo rm -f /etc/yum.repos.d/epel*"
        if $settings['provision_on_boot']
          h.vm.provision :shell, inline: $provision_script
        end
      end
    end
  end
end
