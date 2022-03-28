# frozen_string_literal: true

require "rom/mapper"
require "rom/open_struct"

RSpec.describe ROM::Mapper do
  subject(:mapper) { mapper_class.build }

  let(:mapper_class) do
    user_model = self.user_model

    Class.new(ROM::Mapper) do
      attribute :id
      attribute :name

      model user_model
    end
  end

  let(:relation) do
    [{id: 1, name: "Jane"}, {id: 2, name: "Joe"}]
  end

  let(:user_model) do
    Class.new(ROM::OpenStruct)
  end

  let(:jane) { user_model.new(id: 1, name: "Jane") }
  let(:joe) { user_model.new(id: 2, name: "Joe") }

  describe ".relation" do
    it "inherits from parent" do
      base = Class.new(ROM::Mapper) { relation(:users) }
      virt = Class.new(base)

      expect(virt.relation).to be(:users)
      expect(virt.base_relation).to be(:users)
    end

    it "allows overriding" do
      base = Class.new(ROM::Mapper) { relation(:users) }
      virt = Class.new(base) { relation(:active) }

      expect(virt.config.component.relation).to be(:active)
      expect(virt.base_relation).to be(:users)
    end
  end
end
