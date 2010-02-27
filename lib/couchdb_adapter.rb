require 'rubygems'
require 'pathname'

gem 'dm-core', '~>0.10.2'
require 'dm-core'

gem "couchrest", "~> 0.34"
require "couchrest"

begin
  gem "json"
  require "json/ext"
rescue LoadError
  gem "json_pure"
  require "json/pure"
end


dir = Pathname(__FILE__).dirname.expand_path / 'couchdb_adapter'

require dir / 'attachments'
require dir / 'couch_resource'
require dir / 'json_object'
require dir / 'view'
require dir / 'version'
require dir / 'resource'
require dir / 'adapter'
require dir / 'migrations'
