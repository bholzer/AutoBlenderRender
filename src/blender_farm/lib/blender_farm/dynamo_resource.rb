require 'active_support'
require "active_support/core_ext"
require 'securerandom'
module BlenderFarm
  module DynamoResource
    extend ActiveSupport::Concern

    def self.instance_from_item(item)
      including_classes = ObjectSpace.each_object(Class).select do |c|
        c.included_modules.include?(self)
      end

      item = item.with_indifferent_access
      parsed_key = parse_key(item)

      klass = including_classes.find do |k|
        p k.key_attributes
        [:hk, :rk].all? do |key_name|
          parsed_key[key_name].keys.map(&:to_sym) == k.key_attributes[key_name]
        end
      end

      klass.instance_from_item(item)
    end

    # Given hk and rk with hash-delimited values e.g. "project_id#1234#blend_id#1234"
    # return hash of form {"project_id" => 1234, "blend_id" => 1234}
    def self.parse_key(item)
      Hash[
        item.slice(:hk, :rk).map do |k,v|
          attrs = Hash[v.split("#").each_slice(2).to_a]
          [k, attrs]
        end
      ].with_indifferent_access
    end

    def self.all_for_user(user_id)
      all_items = dynamo_client.query(
        table_name: BlenderFarm.config[:table],
        key_condition_expression: "hk = :hk",
        expression_attribute_values: {
          ":hk" => "user_id##{user_id}"
        }
      ).items

      all_items.map{|item| DynamoResource.instance_from_item(item) }
    end

    # Get the composite key based on key attributes of object
    def key
      self.class.build_key(**key_attributes)
    end

    # Attributes that comprise the composite key for the resource
    def key_attributes
      Hash[
        self.class.key_attributes.values.flatten.map do |attr_name|
          [attr_name, self.send(attr_name)]
        end
      ]
    end

    def get_hierarchy
      descendents = self.class.get_hierarchy(**key_attributes).reject do |item|
        item["hk"] == self.key["hk"] && item["rk"] == self.key["rk"]
      end

      descendents.map{|item| DynamoResource.instance_from_item(item) }
    end

    class_methods do
      # Use the resource's key_attributes to generate
      # a composite key with the provided parameters
      def build_key(**key_params)
        Hash[
          key_attributes.map do |key_name, key_attrs|
            key_pairs = key_attrs.map do |attr|
              [attr.to_s, key_params[attr]].join("#")
            end
            [ key_name, key_pairs.join("#") ]
          end
        ].with_indifferent_access
      end

      def dynamo_client
        @dynamo_client = BlenderFarm.dynamo_client
      end

      def get_dynamo_item(**key_params)
        composite_key = build_key(**key_params)
        dynamo_client.get_item(
          table_name: BlenderFarm.config[:table],
          key: composite_key
        ).item&.with_indifferent_access
      end

      def id_name
        self.name.demodulize.downcase + "_id"
      end

      def create(**create_params)
        if create_params[id_name.to_sym].nil?
          create_params[id_name.to_sym] = SecureRandom.uuid
        end
        key = build_key(**create_params)
        key_params = DynamoResource.parse_key(key).values.reduce(:merge)
        item_attrs = key.merge(create_params)
        item_without_key_attrs = item_attrs.except(*key_params.keys)
        dynamo_client.put_item(table_name: BlenderFarm.config[:table], item: item_without_key_attrs)
        instance_from_item(item_attrs.symbolize_keys)
      end

      def instance_from_item(item)
        item = item.with_indifferent_access
        key_params = DynamoResource.parse_key(item).values.reduce(:merge)
        all_attributes = item.merge(key_params).except(:hk, :rk)

        new(**all_attributes.symbolize_keys)
      end

      # Accepts the resource params that comprise the key of the item
      # Returns an instance of the resource that matched the params
      def find(**key_params)
        dynamo_item = get_dynamo_item(**key_params)
        return nil if dynamo_item.nil?
        instance_from_item(dynamo_item)
      end

      # Get the resource and all descendents
      def get_hierarchy(**key_params)
        eav = build_key(**key_params).transform_keys{|k| ":#{k}" } #Build query expression values from key
        dynamo_client.query(
          table_name: BlenderFarm.config[:table],
          key_condition_expression: "hk = :hk AND begins_with(rk, :rk)",
          expression_attribute_values: eav
        ).items
      end
    end
  end
end
