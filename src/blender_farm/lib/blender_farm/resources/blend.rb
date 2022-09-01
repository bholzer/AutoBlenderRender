require "blender_farm/dynamo_resource"
require 'securerandom'

module BlenderFarm
  module Resources
    class Blend
      include DynamoResource
      attr_accessor :id, :project_id, :user_id
      db_attribute :name

      KEY_TEMPLATE = {
        hk: "user#%{user_id}",
        rk: "project#%{project_id}#blend#%{id}"
      }

      def initialize(id: SecureRandom.uuid, name: nil, project_id:, user_id:)
        @id = id
        @name = name
        @project_id = project_id
        @user_id = user_id
      end

      def key_params
        {
          project_id: project_id,
          user_id: user_id,
          id: id
        }
      end
    end
  end
end
