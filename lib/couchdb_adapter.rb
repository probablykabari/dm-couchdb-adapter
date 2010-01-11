require 'rubygems'
require 'pathname'
$LOAD_PATH
gem 'dm-core', '~>0.10.0'
require 'dm-core'
begin
  gem "json"
  require "json/ext"
rescue LoadError
  gem "json_pure"
  require "json/pure"
end
require 'net/http'
require 'uri'

dir = Pathname(__FILE__).dirname.expand_path / 'couchdb_adapter'

require dir / 'attachments'
require dir / 'couch_resource'
require dir / 'json_object'
require dir / 'view'
require dir / 'version'
require dir / 'resource'
require dir / 'adapter'
