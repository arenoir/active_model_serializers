require 'active_model/array_serializer'
require 'active_model/serializable'
require 'active_model/serializer/associations'
require 'active_model/serializer/params_adapter'
require 'active_model/serializer/config'

require 'thread'

module ActiveModel
  class Serializer
    include Serializable

    @mutex = Mutex.new

    class << self
      def inherited(base)
        base._root = _root
        base._attributes = (_attributes || []).dup
        base._associations = (_associations || {}).dup
      end

      def setup
        @mutex.synchronize do
          yield CONFIG
        end
      end

      def embed(type, options={})
        CONFIG.embed = type
        CONFIG.embed_in_root = true if options[:embed_in_root] || options[:include]
        ActiveSupport::Deprecation.warn <<-WARN
** Notice: embed is deprecated. **
The use of .embed method on a Serializer will be soon removed, as this should have a global scope and not a class scope.
Please use the global .setup method instead:
ActiveModel::Serializer.setup do |config|
  config.embed = :#{type}
  config.embed_in_root = #{CONFIG.embed_in_root || false}
end
        WARN
      end

      if RUBY_VERSION >= '2.0'
        def serializer_for(resource)
          if resource.respond_to?(:to_ary)
            ArraySerializer
          else
            begin
              Object.const_get "#{resource.class.name}Serializer"
            rescue NameError
              nil
            end
          end
        end
      else
        def serializer_for(resource)
          if resource.respond_to?(:to_ary)
            ArraySerializer
          else
            "#{resource.class.name}Serializer".safe_constantize
          end
        end
      end

      attr_accessor :_root, :_attributes, :_associations
      alias root  _root=
      alias root= _root=

      def root_name
        name.demodulize.underscore.sub(/_serializer$/, '') if name
      end

      def attributes(*attrs)
        @_attributes.concat attrs

        attrs.each do |attr|
          define_method attr do
            object.read_attribute_for_serialization attr
          end unless method_defined?(attr)
        end
      end

      def has_one(*attrs)
        associate(Association::HasOne, *attrs)
      end

      def has_many(*attrs)
        associate(Association::HasMany, *attrs)
      end

      private

      def associate(klass, *attrs)
        options = attrs.extract_options!

        attrs.each do |attr|
          define_method attr do
            object.send attr
          end unless method_defined?(attr)

          @_associations[attr] = klass.new(attr, options)
        end
      end
    end

    def initialize(object, options={})
      @object        = object
      @scope         = options[:scope]
      @root          = options.fetch(:root, self.class._root)
      @meta_key      = options[:meta_key] || :meta
      @meta          = options[@meta_key]
      @wrap_in_array = options[:_wrap_in_array]
      @params        = options[:params]
      @association_chain = options.fetch(:association_chain, [])
    end
    attr_accessor :object, :scope, :root, :meta_key, :meta, :params, :association_chain


    def json_key
      if root == true || root.nil?
        self.class.root_name
      else
        root
      end
    end

    def attributes
      attribute_keys.each_with_object({}) do |name, hash|
        hash[name] = send(name)
      end
    end

    def associations
      associations = self.class._associations
      
      associations.each_with_object({}) do |(name, association), hash|        
        if include_association?(association)
          if association.embed_ids?
            hash[association.key] = serialize_ids association
          elsif association.embed_objects?
            associated_data = send(association.name)
            hash[association.embedded_key] = serialize(association, associated_data)
          end
        end
      end
    end

    def filter_attributes(keys)
      keys
    end

    def filter_associations(keys)
      keys
    end

    def embedded_in_root_associations
      associations = self.class._associations

      associations.each_with_object({}) do |(name, association), hash| 
        if association.embed_in_root?
          association_object     = send(association.name)
          association_serializer = build_serializer(association, association_object)

          if include_association?(association)
            serialized_object      = association_serializer.serializable_object
            key                    = association.root_key
            
            hash.merge! association_serializer.embedded_in_root_associations

            if hash.has_key?(key)
              hash[key].concat(serialized_object).uniq!
            else
              hash[key] = serialized_object
            end

          elsif include_nested_association?(association)
            hash.merge!(association_serializer.embedded_in_root_associations)
          end
        end
      end
    end

    def build_serializer(association, object)
      _options = {
        scope: scope,
        params: params,
        association_chain: association_chain_for(association)
      }

      association.build_serializer(object, _options)
    end

    def serialize(association, object)
      build_serializer(association, object).serializable_object
    end

    def serialize_ids(association)
      associated_data = send(association.name)
      if associated_data.respond_to?(:to_ary)
        associated_data.map { |elem| elem.read_attribute_for_serialization(association.embed_key) }
      else
        associated_data.read_attribute_for_serialization(association.embed_key) if associated_data
      end
    end

    def serializable_object(options={})
      return @wrap_in_array ? [] : nil if @object.nil?
      hash = attributes
      hash.merge! associations
      @wrap_in_array ? [hash] : hash
    end

    alias_method :serializable_hash, :serializable_object

    private

      def attribute_keys
        @attribute_keys ||= filter_attribute_keys
      end

      def filter_attribute_keys
        keys = filter_attributes(self.class._attributes.dup)
        
        if params_keyset
          keys = keys & params_keyset
        end

        return keys
      end

      def params_keyset
        @params_keyset ||= params && params.keyset(json_key.to_sym, association_chain)
      end

      def include_association?(association)
        association_keys.include?(association.name.to_sym)
      end

      def association_keys
        @association_keys ||= filter_association_keys
      end

      def filter_association_keys
        keys = filter_associations(self.class._associations.keys)

        if params_include_keys
          keys = keys & params_include_keys
        end
        
        return keys
      end

      def params_include_keys
        params && params.include_keys(association_chain)
      end

      def include_nested_association?(association)
        chain = association_chain_for(association)

        puts association_chain.join('.') + association.name.to_s

        params && params.nested_associations?(chain)
      end

      def association_chain_for(association)
        association_chain.dup.push(association.name.to_sym)
      end

  end
end
