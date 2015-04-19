module ActiveModel
  class Serializer
    class Adapter
      class JsonApi < Adapter
        def initialize(serializer, options = {})
          super
          serializer.root = true
          @hash = {}
          @top = @options.fetch(:top) { @hash }

          @association_chain = ActiveModel::Serializer::AssociationChain.new(options.delete(:include))

          if fields = options.delete(:fields)
            @fieldset = ActiveModel::Serializer::Fieldset.new(fields, serializer.json_key)
          else
            @fieldset = options[:fieldset]
          end
        end

        def serializable_hash(options = {})
          @root = (@options[:root] || serializer.json_key.to_s.pluralize).to_sym

          if serializer.respond_to?(:each)
            @hash[@root] = serializer.map do |s|
              self.class.new(s, @options.merge(top: @top, fieldset: @fieldset)).serializable_hash[@root]
            end
          else
            @hash[@root] = attributes_for_serializer(serializer, @options)

            add_resource_links(@hash[@root], serializer)
          end

          @hash
        end

      private

        def add_links(hash, name, serializers)
          type = serializers.object_type
          ids  = serializers.map { |serializer| serializer.id.to_s }
          
          if !type || name.to_s == type
            hash[:links][name] ||= []
            hash[:links][name] = ids
          else
            hash[:links][name] ||= {}
            hash[:links][name][:type] = type
            hash[:links][name][:ids] = ids
          end
        end

        def add_link(resource, name, serializer)
          resource[:links] ||= {}
          resource[:links][name] = nil

          if serializer
            type = serializer.object_type

            if name.to_s == type || !type
              resource[:links][name] = serializer.id.to_s
            else
              resource[:links][name] ||= {}
              resource[:links][name][:type] = type
              resource[:links][name][:id] = serializer.id.to_s
            end
          end
        end


        def add_linked(assocation_name, serializer, chain = [])

          chain << assocation_name

          if include_association?(chain)
            plural_name = assocation_name.to_s.pluralize.to_sym
            attrs = [attributes_for_serializer(serializer, @options)].flatten

            @top[:linked] ||= {}
            @top[:linked][plural_name] ||= []

            attrs.each do |attrs|
              add_resource_links(attrs, serializer, add_linked: false)

              @top[:linked][plural_name].push(attrs) unless @top[:linked][plural_name].include?(attrs)
            end
          end

          if associations = associations_for(chain)
            serializer.each_association do |name, association, opts|
              # puts 
              # print associations.join(',') + " | " + name.to_s
              # if name == :roles
              #   puts chain.join('-')
              # end
              # if !associations.include?(name)
              #   print ' no'  
              # end
              # puts

              if association && associations.include?(name)
                add_linked(name, association, chain) 
              end
            end
          end
        end
  

        def associations_for(chain)
          @association_chain && @association_chain.associations_for(chain)
        end


        def include_association?(chain)
          @association_chain && @association_chain.include?(chain)
        end

        def included_nested_association?(chain, assocation)
           @association_chain.include?(chain)
        end

        def attributes_for_serializer(serializer, options)
          options[:fields] = @fieldset && @fieldset.fields_for(serializer)

          attributes = serializer.attributes(options)
          attributes[:id] = attributes[:id].to_s if attributes[:id]
          attributes
        end

        def included_association?(serializer)
          @association_key && @association_key.include?(serializer)
        end




        def add_resource_links(attrs, serializer, options = {})
          options[:add_linked] = options.fetch(:add_linked, true)

          Array(serializer).first.each_association do |name, association, opts|
            attrs[:links] ||= {}

            if association.respond_to?(:each)
              add_links(attrs, name, association)
            else
              add_link(attrs, name, association)
            end

            if @options[:embed] != :ids && options[:add_linked]
              Array(association).each do |association|
                add_linked(name, association)
              end
            end
          end
        end
      end
    end
  end
end
