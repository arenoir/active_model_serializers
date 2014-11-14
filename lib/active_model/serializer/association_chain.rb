module ActiveModel
  class Serializer
    class AssociationChain
      
      attr_accessor :association_chain

      def initialize(chain)
        @association_chain = parse(chain)
      end

      def associations_for(chain)
        return unless association_chain
        association_chain.find_all { |a| (a - chain) }.map!(&:first)
      end

      def include?(chain)
        association_chain.any? { |a| a == chain }
      end

      private

      def parse(assoc)
        if assoc.is_a?(Array)
          assoc.map { |key| key.split('.').map(&:to_sym) }
        elsif assoc.is_a?(String)
          assoc.split(',').map { |key| key.split('.').map(&:to_sym) }
        end
      end

    end

  end

end
