node default {
  Exec <||> {
    path => ['/bin','/sbin','/usr/bin','/usr/sbin']
  }
  notice("Host: ${::clientcert} matched default group")
  hiera_include('classes')
}
