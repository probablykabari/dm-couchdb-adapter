require 'pathname'
require 'rubygems'
require "rake"

ROOT    = Pathname(__FILE__).dirname.expand_path
JRUBY   = RUBY_PLATFORM =~ /java/
WINDOWS = Gem.win_platform?
SUDO    = (WINDOWS || JRUBY) ? '' : ('sudo' unless ENV['SUDOLESS'])

require ROOT + 'lib/couchdb_adapter/version'

GEM_NAME = 'dm-couchdb-adapter'
GEM_VERSION = DataMapper::CouchDBAdapter::VERSION
GEM_DEPENDENCIES = [['dm-core', "~>#{GEM_VERSION}"], ['mime-types', '~>1.15']]
GEM_CLEAN = %w[ log pkg coverage ]
GEM_EXTRAS = { :has_rdoc => true, :extra_rdoc_files => %w[ README.txt LICENSE TODO History.txt ] }



begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = GEM_NAME
    gem.summary = %Q{CouchDB Adapter for DataMapper}
    gem.email = 'kabari [a] gmail [d] com'
    gem.homepage = "http://github.com/kabari/#{GEM_NAME}/tree/master"
    gem.authors = ["Kabari Hendrick"]
    # gem is a Gem::Specification... see 
    #  for additional settings
    gem.required_ruby_version = '>= 1.8.6'
    gem.add_dependency("extlib", ">= 0.9.11")
    gem.add_dependency('mime-types', '~>1.15')
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
  spec.fail_on_error = false
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end


task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "#{GEM_NAME} #{GEM_VERSION}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include("LICENSE") 
  rdoc.rdoc_files.include("TODO") 
  rdoc.rdoc_files.include("History.txt")
  rdoc.rdoc_files.include('lib/**/*.rb')
end

