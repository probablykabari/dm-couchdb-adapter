module DataMapper  
  module Couch
    module Conditions
      include DataMapper::Query::Conditions
      
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
    end # end Collection
  end # end Couch
end 
