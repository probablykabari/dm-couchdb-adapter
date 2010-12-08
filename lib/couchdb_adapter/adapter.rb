module DataMapper
  module Adapters
    class CouchDBAdapter < AbstractAdapter
      ConnectionError = Class.new(StandardError)
      
      # Persists one or many new resources
      #
      # @example
      #   adapter.create(collection)  # => 1
      #
      # Adapters provide specific implementation of this method
      #
      # @param [Enumerable<Resource>] resources
      #   The list of resources (model instances) to create
      #
      # @return [Integer]
      #   The number of records that were actually saved into the data-store
      #
      # @api semipublic
      def create(resources)
        raise NotImplementedError, "#{self.class}#create not implemented"
      end

      # Reads one or many resources from a datastore
      #
      # @example
      #   adapter.read(query)  # => [ { 'name' => 'Dan Kubb' } ]
      #
      # Adapters provide specific implementation of this method
      #
      # @param [Query] query
      #   the query to match resources in the datastore
      #
      # @return [Enumerable<Hash>]
      #   an array of hashes to become resources
      #
      # @api semipublic
      def read(query)
        with_connection do |connection|
          
        end
      end

      # Updates one or many existing resources
      #
      # @example
      #   adapter.update(attributes, collection)  # => 1
      #
      # Adapters provide specific implementation of this method
      #
      # @param [Hash(Property => Object)] attributes
      #   hash of attribute values to set, keyed by Property
      # @param [Collection] collection
      #   collection of records to be updated
      #
      # @return [Integer]
      #   the number of records updated
      #
      # @api semipublic
      def update(attributes, collection)
        raise NotImplementedError, "#{self.class}#update not implemented"
      end

      # Deletes one or many existing resources
      #
      # @example
      #   adapter.delete(collection)  # => 1
      #
      # Adapters provide specific implementation of this method
      #
      # @param [Collection] collection
      #   collection of records to be deleted
      #
      # @return [Integer]
      #   the number of records deleted
      #
      # @api semipublic
      def delete(collection)
        raise NotImplementedError, "#{self.class}#delete not implemented"
      end
      
      # Returns the name of the CouchDB database.
      #
      # @raise [RuntimeError] if the CouchDB database name is invalid.
      def db_name
        result = options[:path].scan(/^\/?([-_+%()$a-z0-9]+?)\/?$/).flatten[0]
        if result != nil
          return Addressable::URI.unencode_component(result)
        else
          raise StandardError, "Invalid database path: '#{options[:path]}'"
        end
      end

      # Returns the name of the CouchDB database after being escaped.
      def escaped_db_name
        return Addressable::URI.encode_component(
          self.db_name, Addressable::URI::CharacterClasses::UNRESERVED)
      end

            
      private
      
      def initialize(repo_name, options = {})
        super
        
        # When giving a repository URI rather than a hash, the database name
        # is :path, with a leading slash.
        if options[:path] && options[:database].nil?
          options[:database] = db_name
        end
        
        @resource_naming_convention = NamingConventions::Resource::Underscored
        @uri = Addressable::URI.new(options.only(:scheme, :host, :path, :port))
      end
      
      
      # Returns the CouchRest::Database instance for this process.
      #
      # @return [CouchRest::Database]
      #
      # @raise [ConnectionError]
      #   If the database requires you to authenticate, and the given username
      #   or password was not correct, a ConnectionError exception will be
      #   raised.
      #
      # @api semipublic
      def database
        unless defined?(@database)
          @database = connection.database!(@options[:database])
        end
        @database
      rescue Errno::ECONNREFUSED
        DataMapper.logger.error("Could Not Connect to Database!")
        raise(ConnectionError, "The adapter could not connect to Couchdb running at '#{@uri}'")
      end
      
      def with_connection
        begin
          yield connection
        rescue => e
          DataMapper.logger.error(exception.to_s)
          raise e
        end
      end
      
      # @see #connection
      def connection
        @connection ||= open_connection
      end
      
      # Returns CouchRest::Server instance
      # @return [CouchRest::Server]
      # @todo reset! connection and allow #uuid_batch_count to change
      #       also....do I need to use #chainable for this?
      # @api semipublic
      def open_connection
        CouchRest::Server.new(@uri)
      end
    end # CouchDBAdapter

    # Required naming scheme.
    CouchdbAdapter = CouchDBAdapter
    const_added(:CouchdbAdapter)
  end
end
