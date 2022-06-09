require "blender_farm/dynamo_resource"

module BlenderFarm
  module Resources
    class Project
      include DynamoResource

      attr_accessor :user_id, :project_id, :name, :blends

      def self.key_attributes
        {
          hk: [:user_id],
          rk: [:project_id]
        }
      end

      def initialize(user_id:, project_id:, name:)
        @user_id = user_id
        @project_id = project_id
        @name = name
        @blends = []
      end

      def add_blend(blend)
        @blends << blend
        blend.project = self
      end
    end
  end
end

