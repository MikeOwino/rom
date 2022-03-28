# frozen_string_literal: true

require "rom/transformer"

RSpec.describe ROM::Transformer do
  subject(:relation) do
    rom.relations[:users]
  end

  let(:rom) do
    ROM.setup(:memory) do |config|
      config.relation(:users)

      config.register_mapper(default_mapper)
      config.register_mapper(json_mapper)
    end
  end

  let(:default_mapper) do
    Class.new(ROM::Transformer) do
      config.component.id = :default
      config.component.namespace = :users

      map do
        rename_keys user_id: :id
      end
    end
  end

  let(:json_mapper) do
    Class.new(default_mapper) do
      config.component.id = :json
      config.component.namespace = :users

      map do
        deep_stringify_keys
      end
    end
  end

  it "works with rom runtime" do
    relation.insert(user_id: 1, name: "Jane")

    expect(relation.map_with(:default).to_a).to eql([id: 1, name: "Jane"])
    expect(relation.map_with(:json).to_a).to eql(["id" => 1, "name" => "Jane"])
  end
end
