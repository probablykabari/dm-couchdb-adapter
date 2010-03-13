require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

# shared adapter spec
require File.join(File.dirname(__FILE__), *%w[.. shared adapter_shared_spec])

describe DataMapper::Adapters::CouchDBAdapter do
  it_should_behave_like "An Adapter"
end