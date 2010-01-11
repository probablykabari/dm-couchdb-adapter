module DataMapper
  module Resource
    # Converts a Resource to a JSON representation.
    def to_couch_json(dirty = false)
      property_list = self.class.properties.select { |key, value| dirty ? self.dirty_attributes.key?(key) : true }
      data = {}
      for property in property_list do
        data[property.field] =
          if property.type.respond_to?(:dump)
            property.type.dump(property.get!(self), property)
          else
            property.get!(self)
          end
      end
      data.delete('_attachments') if data['_attachments'].nil? || data['_attachments'].empty?
      data.to_json
    end
  end
end
