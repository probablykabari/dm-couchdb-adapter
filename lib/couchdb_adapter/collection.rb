module DataMapper
  module Couch 
    class Collection < Collection
      attr_accessor :total_rows, :offset
    end
  end
end