require 'blender_farm'

class TestResource
  include BlenderFarm::DynamoResource

  KEY_TEMPLATE = {
    hk: "user#%{hk_var}",
    rk: "attr#%{rk_var}"
  }

  def initialize(hk_var, rk_var)
    @hk_var = hk_var
    @rk_var = rk_var
  end

  def key_params
    {hk_var: @hk_var, rk_var: @rk_var}
  end
end

describe BlenderFarm::DynamoResource do
  describe "key" do
    it "can be parsed with hash-delimited hk and rk" do
      parsed = BlenderFarm::DynamoResource.parse_key({
        hk: "key1#foo",
        rk: "key2#bar#key3#baz"
      })

      expect(parsed).to include({
        key1: "foo",
        key2: "bar",
        key3: "baz"
      })
    end

    it "is generated based on KEY_TEMPLATE and key_params" do
      resource = TestResource.new("foo", "bar")
      expect(resource.key).to include({
        hk: TestResource::KEY_TEMPLATE[:hk] % resource.key_params,
        rk: TestResource::KEY_TEMPLATE[:rk] % resource.key_params
      })
    end
  end

  describe "persistence" do
    it "on an instantiated model" do
      resource = TestResource.new("foo", "bar")
      resource.put

      found = TestResource.find({
        hk_var: "foo",
        rk_var: "bar"
      })

      expect(found.count).to be > 0
    end
  end
end