module DataMapper
  module Couch
    module Model
      def new_collection(query, resources = nil, &block)
        Couch::Collection.new(query, resources, &block)
      end
    end
  end
end