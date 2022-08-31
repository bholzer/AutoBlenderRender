require "blender_farm/dynamo_resource"
require 'securerandom'

module BlenderFarm
  module Resources
    class Project
      include DynamoResource
      attr_accessor :id, :user, :blends
      db_attribute :name

      KEY_TEMPLATE = {
        hk: "user#%{user}",
        rk: "project#%{project}"
      }

      def initialize(id: SecureRandom.uuid, name: nil, blends: [])
        @id = id
        @name = name
        @blends = blends
      end

      def key_params
        {
          project: id,
          user: user.id
        }
      end

      def add_blend(blend)
        @blends << blend
        blend.project = self
      end
    end
  end
end

