module DataMapper
  module Migrations
    module CouchAdapter      
      def create_model_storage(repository, model)
        uri = "/#{self.escaped_db_name}/_design/#{model.base_model.to_s}"
        view = Net::HTTP::Put.new(uri)
        view['content-type'] = "application/json"
        views = model.views.reject {|key, value| value.nil?}
        view.body = { :views => views }.to_json
        request do |http|
          http.request(view)
        end
      end

      def destroy_model_storage(repository, model)
        uri = "/#{self.escaped_db_name}/_design/#{model.base_model.to_s}"
        response = http_get(uri)
        unless response['error']
          uri += "?rev=#{response["_rev"]}"
          http_delete(uri)
        end
      end
    end
  end
end