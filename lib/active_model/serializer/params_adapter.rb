require 'active_model/serializer/config'

module ActiveModel
  class Serializer
    class ParamsAdapter

      def initialize(params, root_name, options = {})
        @params    = params
        @root_name = root_name
        @fieldset_include_key = options[:fieldset_include_key] || :fields
        @association_include_key = options[:association_include_key] || :include
      end

      attr_accessor :params, :root_name, :fieldset_include_key, :association_include_key

      def keyset(_name)
        return if keysets.empty?

        keysets[_name] || []
      end

      def include_keys(chain)
        return if association_chains.empty?

        chains = association_chains.find_all { |_chain| (_chain - chain).size == 1 }
        chains.map!(&:last)
      end

      def nested_associations?(chain)
        return true if association_chains.empty?

        association_chains.any? { |_chain| (_chain - chain).any? }
      end

    private

      def keysets
        @keysets ||= keysets_from_params
      end

      def keysets_from_params
        _params = params[fieldset_include_key]
        _attrs  = {}

        if _params.is_a?(Hash)
          _attrs = _params.inject({}) { |hash,(k,v)| hash[k.to_sym] = v.map(&:to_sym); hash}
        elsif _params.is_a?(Array)
          _attrs[root_name.to_sym] = _params.map(&:to_sym)
        end

        return _attrs
      end

      def association_chains
        @association_chains ||= parse_include_params
      end

      def parse_include_params
        _params = params[association_include_key]

        if _params.is_a?(Array)
          _params.map { |key| key.split('.').map(&:to_sym) }
        else
          []
        end
      end

    end
  end
end