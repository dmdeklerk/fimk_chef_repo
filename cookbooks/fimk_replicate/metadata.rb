name             'fimk_replicate'
maintainer       'Krypto Fin ri'
maintainer_email 'incentivetoken@gmail.com'
license          'All rights reserved'
description      'Setup mysql server for FIMK blockchain replication'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

depends          'apt'
depends          'mysql'
depends          'database'
depends          'mysql2_chef_gem'