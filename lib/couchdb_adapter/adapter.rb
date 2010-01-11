require 'data_objects'

module DataMapper
  module Adapters
    class CouchDBAdapter < AbstractAdapter
      
      # Returns the name of the CouchDB database.
      #
      # Raises an exception if the CouchDB database name is invalid.
      def db_name
        result = @uri.path.scan(/^\/?([-_+%()$a-z0-9]+?)\/?$/).flatten[0]
        if result != nil
          return Addressable::URI.unencode_component(result)
        else
          raise StandardError, "Invalid database path: '#{@uri.path}'"
        end
      end

      # Returns the name of the CouchDB database after being escaped.
      def escaped_db_name
        return Addressable::URI.encode_component(
          self.db_name, Addressable::URI::CharacterClasses::UNRESERVED)
      end

      # Creates a new resources in the specified repository.
      def create(resources)
        created = 0
        resources.each do |resource|
          key = resource.class.key(self.name).map do |property|
            resource.instance_variable_get(property.instance_variable_name)
          end
          if key.compact.empty?
            result = http_post("/#{self.escaped_db_name}", resource.to_couch_json(true))
          else
            result = http_put("/#{self.escaped_db_name}/#{key}", resource.to_couch_json(true))
          end
          if result["ok"]
            resource.id = result["id"]
            resource.rev = result["rev"]
            created += 1
          end
        end
        created
      end

      # Deletes the resource from the repository.
      def delete(query)
        deleted = 0
        resources = read_many(query)
        resources.each do |resource|
          key = resource.class.key(self.name).map do |property|
            resource.instance_variable_get(property.instance_variable_name)
          end
          result = http_delete(
            "/#{self.escaped_db_name}/#{key}?rev=#{resource.rev}"
          )
          deleted += 1 if result["ok"]
        end
        deleted
      end

      # Commits changes in the resource to the repository.
      def update(attributes, query)
        updated = 0
        resources = read_many(query)
        resources.each do |resource|
          key = resource.class.key(self.name).map do |property|
            resource.instance_variable_get(property.instance_variable_name)
          end
          result = http_put("/#{self.escaped_db_name}/#{key}", resource.to_couch_json)
          if result["ok"]
            resource.id = result["id"]
            resource.rev = result["rev"]
            updated += 1
          end
        end
        updated
      end

      # Reads in a set from a query.
      def read_many(query)
        doc = request do |http|
          http.request(build_request(query))
        end
        if query.view && query.model.views[query.view.to_sym].has_key?('reduce')
          doc['rows']
        else
          collection =
          if doc['rows'] && !doc['rows'].empty?
            Collection.new(query) do |collection|
              doc['rows'].each do |doc|
                data = doc["value"]
                  collection.load(
                    query.fields.map do |property|
                      property.typecast(data[property.field])
                    end
                  )
              end
            end
          elsif doc['couchdb_type'] &&
                query.model.couchdb_types.collect {|type| type.to_s}.include?(doc['couchdb_type'])
            data = doc
            Collection.new(query) do |collection|
              collection.load(
                query.fields.map do |property|
                  property.typecast(data[property.field])
                end
              )
            end
          else
            Collection.new(query) { [] }
          end
          collection.total_rows = doc && doc['total_rows'] || 0
          collection
        end
      end

      def read_one(query)
        doc = request do |http|
          http.request(build_request(query))
        end
        if doc['rows'] && !doc['rows'].empty?
          data = doc['rows'].first['value']
        elsif !doc['rows'] &&
                doc['couchdb_type'] &&
                query.model.couchdb_types.find {|type| type.to_s == doc['couchdb_type'] }
            data = doc
        end
        if data
          query.model.load(
            query.fields.map do |property|
              property.typecast(data[property.field])
            end,
            query
          )
        end
      end

      def read(query)
        (query.limit == 1) ? read_one(query) : read_many(query)
      end
      
    protected

      # TODO: document
      # @api private
      def normalized_uri
        @normalized_uri ||=
          begin
            query = @options.except(:adapter, :user, :password, :host, :port, :path, :fragment, :scheme, :query, :username, :database)
            query = nil if query.empty?

            ::DataObjects::URI.new(
              @options[:adapter],
              @options[:user] || @options[:username],
              @options[:password],
              @options[:host],
              @options[:port],
              @options[:path] || @options[:database],
              query,
              @options[:fragment]
            ).freeze
          end
      end

      def build_request(query)
        if query.view
          view_request(query)
        elsif query.conditions.is_a?(Array) &&
              query.conditions.length == 1 &&
              query.conditions.first[0] == :eql &&
              query.conditions.first[1].key? &&
              query.conditions.first[2] &&
              (query.conditions.first[2].length == 1 ||
              !query.conditions.first[2].is_a?(Array))
          get_request(query)
        else
          abstract_request(query)
        end
      end

      ##
      # Prepares a REST request to a stored view. If :keys is specified in
      # the view options a POST request will be created per the CouchDB
      # multi-document-fetch API.
      #
      # @param query<DataMapper::Query> the query
      # @return request<Net::HTTPRequest> a request object
      #
      # @api private
      def view_request(query)
        keys = query.view_options.delete(:keys)
        uri = "/#{self.escaped_db_name}/_design/" +
          "#{query.model.base_model.to_s}/" + "_view/" +
          "#{query.view}" +
          "#{query_string(query)}"
        if keys
          request = Net::HTTP::Post.new(uri)
          request.body = { :keys => keys }.to_json
        else
          request = Net::HTTP::Get.new(uri)
        end
        request
      end

      def get_request(query)
        uri = "/#{self.escaped_db_name}/#{query.conditions.first[2]}"
        request = Net::HTTP::Get.new(uri)
      end

      ##
      # Prepares a REST request to a temporary view. Though convenient for
      # development, "slow" views should generally be avoided.
      #
      # @param query<DataMapper::Query> the query
      # @return request<Net::HTTPRequest> a request object
      #
      # @api private
      def ad_hoc_request(query)
        if query.order.empty?
          key = "null"
        else
          key = (query.order.map do |order|
            "doc.#{order.target.field}"
          end).join(", ")
          key = "[#{key}]"
        end

        request = Net::HTTP::Post.new("/#{self.escaped_db_name}/_temp_view#{query_string(query)}")
        request["Content-Type"] = "application/json"

        couchdb_type_condition = ["doc.couchdb_type == '#{query.model.to_s}'"]
        query.model.descendants.each do |descendant|
          couchdb_type_condition << "doc.couchdb_type == '#{descendant.to_s}'"
        end
        couchdb_type_conditions = couchdb_type_condition.join(' || ')

        if query.conditions.empty?
          request.body =
%Q({"map":
  "function(doc) {
  if (#{couchdb_type_conditions}) {
    emit(#{key}, doc);
    }
  }"
}
)
        else
          conditions = query.conditions.map do |operator, property, value|
            if operator == :eql && value.is_a?(Array)
              value.map do |sub_value|
                json_sub_value = sub_value.to_json.gsub("\"", "'")
                "doc.#{property.field} == #{json_sub_value}"
              end.join(" || ")
            else
              json_value = value.to_json.gsub("\"", "'")
              condition = "doc.#{property.field}"
              condition << case operator
              when :eql   then " == #{json_value}"
              when :not   then " != #{json_value}"
              when :gt    then " > #{json_value}"
              when :gte   then " >= #{json_value}"
              when :lt    then " < #{json_value}"
              when :lte   then " <= #{json_value}"
              when :like  then like_operator(value)
              end
            end
          end
          request.body =
%Q({"map":
  "function(doc) {
    if ((#{couchdb_type_conditions}) && #{conditions.join(' && ')}) {
      emit(#{key}, doc);
    }
  }"
}
)
        end
        request
      end
      
      def abstract_request(query)
        conditions, bind_values = conditions_statement(query, false)
      end
      
      module CouchConditions
        # TODO: document
        # @api semipublic
        def property_to_column_name(property, qualify)
          property.field
        end
        
        private
        # Constructs couchdb if statement
        #
        # @return [String]
        #   where clause
        #
        # @api private
        def conditions_statement(conditions, qualify = false)
          case conditions
            when Query::Conditions::NotOperation
              negate_operation(conditions, qualify)

            when Query::Conditions::AbstractOperation
              # TODO: remove this once conditions can be compressed
              if conditions.operands.size == 1
                # factor out operations with a single operand
                conditions_statement(conditions.operands.first, qualify)
              else
                operation_statement(conditions, qualify)
              end

            when Query::Conditions::AbstractComparison
              comparison_statement(conditions, qualify)

            when Array
              statement, bind_values = conditions  # handle raw conditions
              [ "(#{statement})", bind_values ]
          end
        end

        # TODO: document
        # @api private
        def negate_operation(operation, qualify)
          @negated = !@negated
          begin
            conditions_statement(operation.operands.first, qualify)
          ensure
            @negated = !@negated
          end
        end

        def query_string(query)
          query_string = []
          if query.view_options
            query_string +=
              query.view_options.map do |key, value|
                if [:endkey, :key, :startkey].include? key
                  URI.escape(%Q(#{key}=#{value.to_json}))
                else
                  URI.escape("#{key}=#{value}")
                end
              end
          end
          query_string << "limit=#{query.limit}" if query.limit
          query_string << "descending=#{query.add_reversed?}" if query.add_reversed?
          query_string << "skip=#{query.offset}" if query.offset != 0
          query_string.empty? ? nil : "?#{query_string.join('&')}"
        end

        
        # TODO: document
        # @api private
        def operation_statement(operation, qualify)
          statements  = []
          bind_values = []

          operation.each do |operand|
            statement, values = conditions_statement(operand, qualify)

            if operand.respond_to?(:operands) && operand.operands.size > 1
              statement = "(#{statement})"
            end

            statements << statement
            bind_values.concat(values)
          end

          join_with = operation.kind_of?(@negated ? Query::Conditions::OrOperation : Query::Conditions::AndOperation) ? '&&' : '||'
          statement = statements.join(" #{join_with} ")

          return statement, bind_values
        end

        # Constructs comparison clause
        #
        # @return [String]
        #   comparison clause
        #
        # @api private
        def comparison_statement(comparison, qualify)
          value = comparison.value.to_json.gsub("\"", "'")

          # TODO: move exclusive Range handling into another method, and
          # update conditions_statement to use it

          # break exclusive Range queries up into two comparisons ANDed together
          if value.kind_of?(Range) && value.exclude_end?
            operation = Query::Conditions::Operation.new(:and,
              Query::Conditions::Comparison.new(:gte, comparison.subject, value.first),
              Query::Conditions::Comparison.new(:lt,  comparison.subject, value.last)
            )

            statement, bind_values = conditions_statement(operation, qualify)

            return "(#{statement})", bind_values
          elsif comparison.relationship?
            return conditions_statement(comparison.foreign_key_mapping, qualify)
          end

          operator = case comparison
            when Query::Conditions::EqualToComparison              then @negated ? '!=' : '=='
            when Query::Conditions::InclusionComparison            then @negated ? exclude_operator(comparison.subject, value)    : include_operator(comparison.subject, value)
            when Query::Conditions::RegexpComparison               then @negated ? not_regexp_operator(value) : regexp_operator(value)
            when Query::Conditions::LikeComparison                 then @negated ? unlike_operator(value)     : like_operator(value)
            when Query::Conditions::GreaterThanComparison          then @negated ? ' <= '                       : ' > '
            when Query::Conditions::LessThanComparison             then @negated ? ' >= '                       : ' < '
            when Query::Conditions::GreaterThanOrEqualToComparison then @negated ? ' < '                        : ' >= '
            when Query::Conditions::LessThanOrEqualToComparison    then @negated ? ' > '                        : ' <= '
          end

          # if operator return value contains ? then it means that it is function call
          # and it contains placeholder (%s) for property name as well (used in Oracle adapter for regexp operator)
          if operator.include?('?')
            return operator % property_to_column_name(comparison.subject, qualify), [ value ]
          else
            return "doc.#{property_to_column_name(comparison.subject, qualify)}#{operator}#{value}".strip, [value].compact
          end
        end

        # TODO: document
        # @api private
        def include_operator(property, operand)
          case operand
            when Array then 'IN'
            when Range then 'BETWEEN'
          end
        end

        # TODO: document
        # @api private
        def exclude_operator(property, operand)
          "NOT #{include_operator(property, operand)}"
        end

        # TODO: document
        # @api private
        def regexp_operator(operand)
          '~'
        end

        # TODO: document
        # @api private
        def not_regexp_operator(operand)
          '!~'
        end

        # TODO: document
        # @api private
        def like_operator(value)
          case value
          when Regexp then value = value.source
          when String
            # We'll go ahead and transform this string for SQL compatability
            value = "^#{value}" unless value[0..0] == ("%")
            value = "#{value}$" unless value[-1..-1] == ("%")
            value.gsub!("%", ".*")
            value.gsub!("_", ".")
          end
          return "match(/#{value}/)"
        end
        
        # TODO: document
        # @api private
        def unlike_operator(value)
          # how the hell...
        end
        
      end # end CouchJS
      include CouchConditions
      
      module HTTPAbstraction
        private
        def http_put(uri, data = nil)
          DataMapper.logger.debug("PUT #{uri}")
          request { |http| http.put(uri, data) }
        end

        def http_post(uri, data)
          DataMapper.logger.debug("POST #{uri}")
          request { |http| http.post(uri, data) }
        end

        def http_get(uri)
          DataMapper.logger.debug("GET #{uri}")
          request { |http| http.get(uri) }
        end

        def http_delete(uri)
          DataMapper.logger.debug("DELETE #{uri}")
          request { |http| http.delete(uri) }
        end

        def request(parse_result = true, &block)
          res = nil
          Net::HTTP.start(@uri.host, @uri.port) do |http|
            res = yield(http)
          end
          JSON.parse(res.body) if parse_result
        end        
      end
      include HTTPAbstraction
      
      private
      def initialize(name, options)
        super(name, options)
        @resource_naming_convention = NamingConventions::Resource::Underscored
        @uri = normalized_uri
      end
      
      module Migration
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
      include Migration
    end

    # Required naming scheme.
    CouchdbAdapter = CouchDBAdapter
  end
end
