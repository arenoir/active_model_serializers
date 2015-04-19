module ActiveModel
  class Serializer
    class AssociationChain
      
      attr_accessor :association_chain

      def initialize(chain)
        @association_chain = parse(chain)
      end

      def associations_for(chain)
        association_chain.map { |a| (a - chain).first }.compact
      end

      def include?(chain)
        association_chain.any? { |a| a == chain }
      end

      def include_nested_association?(chain)
        association_chain.any? { |a| (a - chain).size > 1 }
      end

      private

      def parse(assoc)
        if assoc.is_a?(Array)
          assoc.map { |key| key.split('.').map(&:to_sym) }
        elsif assoc.is_a?(String)
          assoc.split(',').map { |key| key.split('.').map(&:to_sym) }
        else
          []
        end
      end

    end

  end

end
