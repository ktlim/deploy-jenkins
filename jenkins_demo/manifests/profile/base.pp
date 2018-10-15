class jenkins_demo::profile::base {
  include ::augeas
  include ::sysstat
  include ::irqbalance
  include ::ntp
  include ::timezone
  include ::tuned

  #class { 'firewall': ensure    => 'stopped' }
  #resources { 'firewall': purge => true }

  if $::osfamily == 'RedHat' {
    if $::operatingsystem != 'Fedora' {
      include ::epel
      Class['epel'] -> Package<| provider != 'rpm' |>
    }

    # kludge around yum-cron install failing without latest yum package:
    # https://bugzilla.redhat.com/show_bug.cgi?id=1293713
    package { 'yum': ensure => latest } -> Package['yum-cron']
    # note:
    #   * el6.x will update everything
    #   * the jenkins package is only present on the master
    class { '::yum_autoupdate':
      exclude      => ['kernel*', 'jenkins', 'java*', 'nginx'],
      notify_email => false,
      action       => 'apply',
      update_cmd   => 'security',
    }
  }

  # disable postfix on el6/el7 as we don't need an mta
  service { 'postfix':
    ensure => 'stopped',
    enable => false,
  }
}
