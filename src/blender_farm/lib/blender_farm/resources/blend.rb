require "blender_farm/dynamo_resource"

module BlenderFarm
  module Resources
    class Blend
      include DynamoResource

      attr_accessor :user_id, :project_id, :blend_id, :name

      def self.key_attributes
        {
          hk: [:user_id],
          rk: [:project_id, :blend_id]
        }
      end

      def initialize(user_id:, project_id:, blend_id:, name:)
        @user_id = user_id
        @project_id = project_id
        @blend_id = blend_id
        @name = name
      end

      def project
        @project ||= Project.find(user_id: user_id, project_id: project_id)
      end
    end
  end
end
