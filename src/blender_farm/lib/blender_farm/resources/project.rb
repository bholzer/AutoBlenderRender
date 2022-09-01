require "blender_farm/dynamo_resource"
require 'securerandom'

module BlenderFarm
  module Resources
    class Project
      include DynamoResource
      attr_accessor :id, :user_id
      db_attribute :name

      KEY_TEMPLATE = {
        hk: "user#%{user_id}",
        rk: "project#%{id}"
      }

      def initialize(id: SecureRandom.uuid, name: nil, user_id:)
        @id = id
        @name = name
        @user_id = user_id
      end

      def key_params
        {
          id: id,
          user_id: user_id
        }
      end
    end
  end
end

