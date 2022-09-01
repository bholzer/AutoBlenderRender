require "blender_farm/dynamo_resource"
require 'securerandom'

module BlenderFarm
  module Resources
    class Job
      include DynamoResource
      attr_accessor :id, :blend_id, :project_id, :user_id
      db_attribute :type

      KEY_TEMPLATE = {
        hk: "user#%{user_id}",
        rk: "project#%{project_id}#blend#%{blend_id}#job#%{id}"
      }

      def initialize(id: SecureRandom.uuid, type: nil, blend_id:, project_id:, user_id:)
        @id = id
        @type = type
        @blend_id = blend_id
        @project_id = project_id
        @user_id = user_id
      end

      def key_params
        {
          project_id: project_id,
          user_id: user_id,
          blend_id: blend_id,
          id: id
        }
      end
    end
  end
end
