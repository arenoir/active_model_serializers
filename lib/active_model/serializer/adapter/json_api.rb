module ActiveModel
  class Serializer
    class Adapter
      class JsonApi < Adapter
        def initialize(serializer, options = {})
          super
          serializer.root = true
          @hash = {}
          @top = @options.fetch(:top) { @hash }

          if chain = options[:include]
            @association_chain = ActiveModel::Serializer::AssociationChain.new(chain)
          end

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

            serializer.each_association do |name, serializer, opts|
              @hash[@root][:links] ||= {}
               


                if serializer.respond_to?(:each)
                  add_links(name, serializer, opts)
                else
                  add_link(name, serializer, opts)
                end
            end
          end

          @hash
        end

        def add_links(name, serializer, options)
            type = serializer.object_type
            ids  = serializer.map { |serializer| serializer.id.to_s }

            if !type || name.to_s == type
              @hash[@root][:links][name] ||= []
              @hash[@root][:links][name] = ids
            else
              @hash[@root][:links][name] ||= {}
              @hash[@root][:links][name][:type] = type
              @hash[@root][:links][name][:ids] = ids
            end
          

          unless serializer.none? || @options[:embed] == :ids
            serializer.each { |s| add_linked(name, s) }
          end
        end

        def add_link(name, serializer, options)
          if serializer
            type = serializer.object.class.to_s.underscore
            if name.to_s == type || !type
              @hash[@root][:links][name] = serializer.id.to_s
            else
              @hash[@root][:links][name] ||= {}
              @hash[@root][:links][name][:type] = type
              @hash[@root][:links][name][:id] = serializer.id.to_s
            end

            unless @options[:embed] == :ids
              add_linked(name, serializer)
            end
          else
            @hash[@root][:links][name] = nil
          end
        end

        def add_linked(resource, serializer, chain = [])

          chain << resource 

          if include_association?(chain)
            plural_name = resource.to_s.pluralize.to_sym
            attrs = attributes_for_serializer(serializer, @options)
            @top[:linked] ||= {}
            @top[:linked][plural_name] ||= []
            @top[:linked][plural_name].push attrs unless @top[:linked][plural_name].include? attrs
          end

          return if serializer.nil? || serializer.respond_to?(:each)

          if associations = associations_for(chain)
            serializer.each_association do |name, association, opts|
              if associations.include?(name)
                add_linked(name, association, chain) 
              end
            end
          end

        end


        private

        def associations_for(chain)
          @association_chain && @association_chain.associations_for(chain)
        end


        def include_association?(chain)
          @association_chain && @association_chain.include?(chain)
        end


        def attributes_for_serializer(serializer, options)
          if fields = @fieldset && @fieldset.fields_for(serializer)
            options[:fields] = fields
          end

          attributes = serializer.attributes(options)
          attributes[:id] = attributes[:id].to_s if attributes[:id]
          attributes
        end

        def included_association?(serializer)
          @association_key && @association_key.include?(serializer)
        end

        def included_nested_association?(serializer)
        end

        def include_assoc? assoc
          @options[:include] && @options[:include].split(',').include?(assoc.to_s)
        end
      end
    end
  end
end
