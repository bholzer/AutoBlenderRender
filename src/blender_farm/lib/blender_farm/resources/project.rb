require "blender_farm/dynamo_resource"

module BlenderFarm
  module Resources
    class Project
      include DynamoResource

      def self.key_attributes
        {
          hk: [:user_id],
          rk: [:project_id]
        }
      end

      attr_accessor :user_id, :project_id, :name

      def initialize(user_id:, project_id:, name:)
        @user_id = user_id
        @project_id = project_id
        @name = name
      end
    end
  end
end

