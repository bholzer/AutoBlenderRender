require 'active_support'
require "active_support/core_ext"
require 'securerandom'
module BlenderFarm
  module DynamoResource
    extend ActiveSupport::Concern

    # Given hash with hk and rk containing hash-delimited values e.g. "project_id#1234#blend_id#1234"
    # return hash of form {"project_id" => 1234, "blend_id" => 1234}
    def self.parse_key(item)
      Hash[
        item.slice(:hk, :rk).flat_map do |k,v|
          Hash[v.split("#").each_slice(2).to_a].to_a
        end
      ].with_indifferent_access
    end

    def key
      self.class.generate_key(**key_params)
    end

    # Write the model to the table, updating if a match is found.
    def put
      db_attributes = self.class.db_attributes.map do |attr_name|
        [attr_name, self.send(attr_name)]
      end.to_h

      BlenderFarm.dynamo_client.put_item(
        table_name: BlenderFarm.config[:table],
        item: self.key.merge(db_attributes)
      )
    end

    class_methods do
      # Attributes to store in the table that aren't encoded in the key
      # acts as getter and setter
      def db_attribute(*attrs)
        @db_attributes ||= []
        attr_accessor(*attrs)
        @db_attributes = @db_attributes.push(*attrs).uniq
      end
      alias_method :db_attributes, :db_attribute

      # Using the KEY_TEMPLATE and key_params, generate a composite key
      def generate_key(**key_params)
        Hash[
          self::KEY_TEMPLATE.map{|k,template| [k, template % key_params]  }
        ].with_indifferent_access
      end

      # Finds this item and any descendents
      def find(**key_params)
        key = generate_key(key_params)
        eav = key.transform_keys{|k| ":#{k}"}
        items = BlenderFarm.dynamo_client.query(
          table_name: BlenderFarm.config[:table],
          key_condition_expression: "hk = :hk AND begins_with(rk, :rk)",
          expression_attribute_values: eav
        ).items
      end

      def create(**params)
        instance = self.new(params)
        instance.put
        instance
      end
    end
  end
end
