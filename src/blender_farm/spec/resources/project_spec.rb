# require 'blender_farm'

# describe BlenderFarm::Resources::Project do
#   describe "put" do
#     context "blank model" do
#       it "returns persisted record with proper key" do
#         user = BlenderFarm::Resources::User.new()
#         user.put
#         expect(user.key["hk"]).to eq("user##{user.id}")
#         expect(user.key["rk"]).to eq("USER")
#       end
#     end
#   end
# end