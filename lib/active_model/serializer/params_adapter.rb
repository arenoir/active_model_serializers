require 'active_model/serializer/config'

module ActiveModel
  class Serializer
    class ParamsAdapter

      def initialize(params, options = {})
        fieldset_key = options[:fieldset_param] || :fields
        include_key  = options[:include_param] || :include

        set_keysets params[fieldset_key]
        set_association_chains params[include_key]
      end

      attr_accessor :keysets, :single_keyset, :association_chains

      def keyset(type, chain = [])
        if keysets
          keysets[type] || []
        elsif single_keyset
          chain.empty? ? single_keyset : []
        end
      end

      def include_keys(chain)
        if association_chains
          chains = association_chains.find_all { |_chain| (_chain - chain).size == 1 }
          chains.map!(&:last)
        end
      end

      def nested_associations?(chain)
        return false unless association_chains
        chain.map!(&:to_sym)

        association_chains.any? { |_chain| (_chain - chain).size > 1 }
      end

    private

      def set_keysets(params)
        if params.is_a?(Hash)
          @keysets = params.inject({}) { |hash,(k,v)| hash[k.to_sym] = v.map(&:to_sym); hash}
        elsif params.is_a?(Array)
          @single_keyset = params.map(&:to_sym)
        end
      end

      def set_association_chains(params)
        if params.is_a?(Array)
          @association_chains = params.map { |key| key.split('.').map(&:to_sym) }
        end
      end

    end
  end
end