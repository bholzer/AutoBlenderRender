require "blender_farm/dynamo_resource"
require 'securerandom'

module BlenderFarm
  module Resources
    class User
      include DynamoResource
      attr_accessor :id

      KEY_TEMPLATE = {
        hk: "user#%{id}",
        rk: "USER"
      }

      def initialize(id: SecureRandom.uuid)
        @id = id
      end

      def key_params
        { id: id }
      end
    end
  end
end

