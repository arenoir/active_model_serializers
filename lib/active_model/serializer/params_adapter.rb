require 'active_model/serializer/config'

module ActiveModel
  class Serializer
    class ParamsAdapter

      def initialize(params, root_name, options = {})
        @params    = params
        @root_name = root_name
        @fieldset_include_key = options[:fieldset_include_key] || :includes
        @association_include_key = options[:association_include_key] || :fields
      end

      attr_accessor :params, :root_name, :fieldset_include_key, :association_include_key

      def attributes_for(_name)
        attributes[_name]
      end

      def associations_for(_name)
        associations[_name]
      end

      def include_association?(_chain)
        if associations.empty?
          true
        else
          associations.include?(_chain.join('.'))
        end
      end

      def include_nested_association?(_chain)
        if associations.empty?
          true
        else
          _name = _chain.join('.') + '.'
          associations.any? { |_key| _key.include?(_name) }
        end
      end

    private

      def associations
        @associations ||= associations_from_params
      end

      def attributes
        @attributes ||= attributes_from_params
      end

      def attributes_from_params
        _params = params[fieldset_include_key]
        _attrs  = {}

        if _params.is_a?(Hash)
          _attrs = _params
        elsif _params.is_a?(Array)
          _attrs[root_name] = _params
        end

        return _attrs
      end

      def associations_from_params
        _params = params[association_include_key]
        _assocs = {}
        nested = {}

        if _params.is_a?(Array)
          _nested = _params.select { |key| key =~ /\.+/ }

          _assocs[root_name] = _params - _nested

          _nested.each do |key| 
            _keys = key.split('.')

            _keys.each_with_index do |_key, index|
              nested
            end

          end

        end

        return _assocs
      end
      end
    end
end