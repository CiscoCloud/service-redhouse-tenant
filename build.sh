#!/bin/bash -ex

VERSION=1.0.$(git rev-list HEAD --count)
ERROR=0

check_out() {
  RES=$1
  TARGET=${2:-0}
  if [ $RES -ne $TARGET ]; then
    exit 1
  fi
}

# Ensure build tools are installed
which bundle || sudo gem install bundler
bundle install
check_out $?

# Reset the environment from the previous run
[ -d puppet ] || exit 1
[ -d puppet/modules ] && rm -Rf puppet/modules

# Install latest modules
cd puppet
bundle exec librarian-puppet install
check_out $?

# Remove invalid character encoding for ansible/puppet
find modules -type f -name '*.pp' -exec iconv -c -f UTF8 -t ASCII -o {} {} \; 2> /dev/null

exit $ERROR
