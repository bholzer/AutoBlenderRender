require 'active_support/concern'

module BlenderFarm
  module DynamoResource
    extend ActiveSupport::Concern

    # Get the composite key based on key attributes of object
    def key
      key_attrs = Hash[
        self.class.key_attributes.values.flatten.map do |attr_name|
          [attr_name, self.send(attr_name)]
        end
      ]
      self.class.build_key(**key_attrs)
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
        ]
      end

      def dynamo_client
        @dynamo_client = BlenderFarm.dynamo_client
      end

      def get_dynamo_item(**key_params)
        composite_key = build_key(**key_params)
        dynamo_client.get_item(
          table_name: BlenderFarm.config[:table],
          key: composite_key
        ).item
      end

      # Accepts the resource params that comprise the key of the item
      # Returns an instance of the resource that matched the params
      def find(**key_params)
        dynamo_item = get_dynamo_item(**key_params)
        parsed_key = parse_key(dynamo_item)
        all_attributes = dynamo_item.merge(parsed_key).reject{|k,v| ["hk", "rk"].include?(k) }

        new(**all_attributes.transform_keys(&:to_sym))
      end

      # Given hk and rk with hash-delimited values e.g. "project_id#1234#blend_id#1234"
      # return hash of form {"project_id" => 1234, "blend_id" => 1234}
      def parse_key(item)
        split_keys = item.slice("hk", "rk").values.flat_map{|key| key.split("#") }
        Hash[split_keys.each_slice(2).to_a]
      end
    end
  end
end
