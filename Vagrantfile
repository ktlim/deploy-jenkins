required_plugins = %w{
  vagrant-librarian-puppet
  vagrant-puppet-install
  vagrant-aws
}
plugins_to_install = required_plugins.select { |plugin| not Vagrant.has_plugin? plugin }
if not plugins_to_install.empty?
  puts "Installing plugins: #{plugins_to_install.join(' ')}"
  system "vagrant plugin install #{plugins_to_install.join(' ')}"
  exec "vagrant #{ARGV.join(' ')}"
end

ABS_PATH = File.expand_path(File.dirname(__FILE__))
TF_STATE= "#{ABS_PATH}/terraform/terraform.tfstate"

fail "missing terraform state file: #{TF_STATE}" unless File.exist? TF_STATE
outputs = JSON.parse(File.read(TF_STATE))["modules"].first["outputs"]
outputs.each_pair do |k, v|
  Object.const_set(k.upcase, v)
end

def gen_hostname(boxname)
  "jenkins-#{boxname}"
end

def ci_hostname(hostname, provider, role=nil)
  provider.user_data = <<-EOS
#cloud-config
hostname: #{hostname}
fqdn: #{hostname}
manage_etc_hosts: true
write_files:
  - path: /etc/facter/facts.d/role.txt
    owner: root:root
    permissions: '0644'
    content: "role=#{role}"
  EOS
end

def n_slaves
  (1..3)
end

def ssh_private_key_path
   "#{ABS_PATH}/jenkins_demo/templates/id_rsa"
end

def master_ami
  ENV['MASTER_AMI'] || 'ami-65112355'
end

def centos6_ami
  ENV['CENTOS6_AMI'] || 'ami-bd10228d'
end

def centos7_ami
  ENV['CENTOS7_AMI'] || 'ami-c91321f9'
end

Vagrant.configure('2') do |config|
  config.vm.define 'master', primary: true do |define|
    hostname = gen_hostname('master')
    define.vm.hostname = hostname

    define.vm.provider :aws do |provider, override|
      ci_hostname(hostname, provider, 'master')

      provider.ami = master_ami
      provider.private_ip_address = '192.168.123.10'
      provider.elastic_ip = ELASTIC_IP
      provider.security_groups = [
        SECURITY_GROUP_ID_INTERNAL,
        SECURITY_GROUP_ID_SSH,
        SECURITY_GROUP_ID_HTTP,
      ]
      provider.instance_type = 'c4.large'
      provider.tags = { 'Name' => hostname }
    end

    define.vm.provision "puppet", type: :puppet, preserve_order: true do |puppet|
      puppet.manifests_path = "manifests"
      puppet.module_path = "modules"
      puppet.manifest_file = "default.pp"
      puppet.hiera_config_path = "hiera.yaml"
      puppet.options = [
       '--verbose',
       '--trace',
       '--report',
       '--show_diff',
       '--pluginsync',
       '--disable_warnings=deprecations',
      ]
    end
  end

  n_slaves.each do |slave_id|
    config.vm.define "el6-#{slave_id}" do |define|
      hostname = gen_hostname("el6-#{slave_id}")
      define.vm.hostname = hostname

      define.vm.provider :aws do |provider, override|
        ci_hostname(hostname, provider, 'slave')

        provider.ami = centos6_ami
        provider.tags = { 'Name' => hostname }
      end
    end
  end

  n_slaves.each do |slave_id|
    config.vm.define "el7-#{slave_id}" do |define|
      hostname = gen_hostname("el7-#{slave_id}")
      define.vm.hostname = hostname

      define.vm.provider :aws do |provider, override|
        ci_hostname(hostname, provider, 'slave')

        provider.ami = centos7_ami
        provider.tags = { 'Name' => hostname }
      end
    end
  end

  # setup the remote repo needed to install a current version of puppet
  config.puppet_install.puppet_version = '3.8.5'

  config.vm.provision "puppet", type: :puppet do |puppet|
    puppet.manifests_path = "manifests"
    puppet.module_path = "modules"
    puppet.manifest_file = "default.pp"
    puppet.hiera_config_path = "hiera.yaml"
    puppet.options = [
     '--verbose',
     '--trace',
     '--report',
     '--show_diff',
     '--pluginsync',
     '--disable_warnings=deprecations',
    ]
  end

  config.vm.provider :aws do |provider, override|
    override.vm.box = 'aws'
    override.vm.box_url = "https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box"
    # http://blog.damore.it/2015/01/aws-vagrant-no-host-ip-was-given-to.html
    override.nfs.functional = false
    override.vm.synced_folder '.', '/vagrant', :disabled => true
    override.vm.synced_folder 'hieradata/', '/tmp/vagrant-puppet/hieradata'
    override.ssh.private_key_path = ssh_private_key_path
    provider.keypair_name = DEMO_NAME
    provider.access_key_id = ENV['AWS_ACCESS_KEY_ID']
    provider.secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
    provider.region = AWS_DEFAULT_REGION
    provider.subnet_id = SUBNET_ID
    provider.associate_public_ip = true
    provider.security_groups = [
      SECURITY_GROUP_ID_INTERNAL,
      SECURITY_GROUP_ID_SSH,
    ]
    provider.instance_type = 'c4.xlarge'
    provider.ebs_optimized = true
    provider.block_device_mapping = [{
      'DeviceName'              => '/dev/sda1',
      'Ebs.VolumeSize'          => 200,
      'Ebs.VolumeType'          => 'gp2',
      'Ebs.DeleteOnTermination' => 'true',
    }]
    provider.monitoring = true
    provider.instance_package_timeout = 36600
  end

  if Vagrant.has_plugin?('vagrant-librarian-puppet')
    config.librarian_puppet.placeholder_filename = ".gitkeep"
  end

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.disable!
  end
end

# -*- mode: ruby -*-
# vi: set ft=ruby :
