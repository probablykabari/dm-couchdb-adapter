require File.join(File.dirname(__FILE__), 'spec_helper')

def load_driver(name, default_uri)
  return false if ENV['ADAPTER'] != name.to_s

  begin
    DataMapper.setup(name, ENV["#{name.to_s.upcase}_SPEC_URI"] || default_uri)
    DataMapper::Repository.adapters[:default] =  DataMapper::Repository.adapters[name]
    true
  rescue LoadError => e
    warn "Could not load do_#{name}: #{e}"
    false
  end
end

ENV['ADAPTER'] ||= 'sqlite3'

HAS_SQLITE3  = load_driver(:sqlite3,  'sqlite3::memory:')
HAS_MYSQL    = load_driver(:mysql,    'mysql://localhost/dm_core_test')
HAS_POSTGRES = load_driver(:postgres, 'postgres://postgres@localhost/dm_core_test')

if COUCHDB_AVAILABLE && (HAS_SQLITE3 || HAS_MYSQL || HAS_POSTGRES)
  class ::User
    include DataMapper::Resource

    property :id, Serial
    property :name, String
    
    repository(:couch) do
      has n, :posts
    end
  end
  
  
  class ::Post
    include DataMapper::CouchResource
    
    property :title, String
    property :body, Text
    
    def self.default_repository_name
      :couch
    end
    
    repository(:default) do
      belongs_to :user
    end
  end

  User.auto_migrate!
  
  describe DataMapper::Model, "working with couch resources" do
    before(:all) do
      @user = User.new(:name => "Jamie")
      @user.save.should be_true
    end

    after(:all) do
      @user.destroy.should be_true
      Post.all.destroy!.should be_true
    end
    
    it "should create resources in couch" do
      @user.posts.create(:title => "I'm a little teapot", :body => "this is my handle, this is my spout").should be_true
      Post.first.title.should == "I'm a little teapot"
    end
    
    it "should find child elements" do
      @post = Post.first
      @user.posts.should include(@post)
      @user.posts.length.should == 1
    end
    
    
  end  
end
