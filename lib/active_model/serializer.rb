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
        base._attributes = []
        base._associations = {}
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
      @object   = object
      @scope    = options[:scope]
      @root     = options.fetch(:root, self.class._root)
      @meta_key = options[:meta_key] || :meta
      @meta     = options[@meta_key]
      @params   = options[:params]
      @options  = options.reject{|k,v| [:scope, :root, :meta_key, :meta, :params].include?(k) }
    end
    attr_accessor :object, :scope, :meta_key, :meta, :root, :options, :params, :ancestors

    def json_key
      if root == true || root.nil?
        self.class.root_name
      else
        root
      end
    end

    def attributes
      attributes_keys.each_with_object({}) do |name, hash|
        hash[name] = send(name)
      end
    end

    def associations
      associations = self.class._associations
      
      associations.each_with_object({}) do |(name, association), hash|
        next unless include_association?(association)
        
        if association.embed_ids?
          hash[association.key] = serialize_ids association
        elsif association.embed_objects?
          associated_data = send(association.name)
          hash[association.embedded_key] = serialize(association, associated_data)
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
        if association.embed_in_root? && include_association?(association)
          associated_data = Array(send(association.name))
          hash[association.root_key] = serialize(association, associated_data)
        end
      end
    end

    def serialize(association, object)
      association.build_serializer(object, {scope: scope, params: params}).serializable_object
    end

    def serialize_ids(association)
      associated_data = send(association.name)
      if associated_data.respond_to?(:to_ary)
        associated_data.map { |elem| elem.read_attribute_for_serialization(association.embed_key) }
      else
        associated_data.read_attribute_for_serialization(association.embed_key) if associated_data
      end
    end

    def serializable_hash(options={})
      return nil if object.nil?
      hash = attributes
      hash.merge! associations
    end
    alias_method :serializable_object, :serializable_hash
    
    private

      def include_association?(_association)
        association_keys.include?(_association.name.to_sym) && 
        params_include_association?(_association)
      end
      
      def params_include_association?(_association)
        if params
          _chain = Array(association_chain).push(_association.root_key)
          
          params.include_association?(_association)
        else
          true
        end
      end

      def attributes_keys
        @attributes_keys ||= filtered_attributes_keys
      end

      def filtered_attributes_keys
        _attr_keys   = filter_attributes(self.class._attributes.dup)
        _filter_keys = params && params.attributes_for(json_key)
        
        if _filter_keys
          _attr_keys = _attr_keys & _filter_keys
        end

        return _attr_keys
      end

      def association_keys
        @association_keys ||= filtered_association_keys
      end

      def filtered_association_keys
        _assocations = self.class._associations
        _assoc_keys  = filter_associations(_assocations.keys)
        _param_keys = params && params.associations_for(json_key)

        if _param_keys
           _assoc_keys = _assoc_keys & _param_keys
         end
        
        return _assoc_keys
      end
    
  end
end
