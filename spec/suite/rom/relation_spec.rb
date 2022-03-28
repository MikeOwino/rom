# frozen_string_literal: true

require "rom/memory"

RSpec.describe ROM::Relation do
  subject(:relation) do
    Class.new(ROM::Relation) do
      config.component.adapter = :test
      config.component.id = :users
    end.new(dataset)
  end

  let(:dataset) { ROM::Memory::Dataset.new([jane, joe]) }

  let(:jane) { {id: 1, name: "Jane"} }
  let(:joe) { {id: 2, name: "Joe"} }

  describe ".[]" do
    before do
      module Test::TestAdapter
        class Relation < ROM::Relation
          config.component.adapter = :test

          def test_relation?
            true
          end
        end
      end

      module Test::BrokenAdapter
        class Relation < ROM::Relation
          def test_relation?
            true
          end
        end
      end

      ROM.register_adapter(:test, Test::TestAdapter)
      ROM.register_adapter(:broken, Test::BrokenAdapter)
    end

    it "returns relation subclass from the registered adapter" do
      subclass = Class.new(ROM::Relation[:test]) { schema(:test) {} }

      relation = subclass.new([])

      expect(relation).to be_test_relation
    end
  end

  describe "#name" do
    context "missing dataset" do
      context "with Relation inside module" do
        before do
          module Test::Test
            class SuperRelation < ROM::Relation[:memory]
              schema {}
            end
          end
        end

        it "returns name based on class" do
          relation = Test::Test::SuperRelation.new([])

          expect(relation.name).to eql(ROM::Relation::Name[:super_relation])
        end
      end

      context "with Relation without module" do
        before do
          class Test::SuperRelation < ROM::Relation[:memory]
            schema {}
          end
        end

        it "returns name based only on class" do
          relation = Test::SuperRelation.new([])

          expect(relation.name).to eql(ROM::Relation::Name[:super_relation])
        end
      end

      context "with a descendant relation" do
        before do
          class Test::SuperRelation < ROM::Relation[:memory]
            schema {}
          end

          class Test::DescendantRelation < Test::SuperRelation
            schema {}
          end
        end

        it "sets custom relation schema" do
          relation = Test::DescendantRelation.new([])

          expect(relation.name).to eql(ROM::Relation::Name[:descendant_relation])
        end
      end
    end

    context "manualy set dataset" do
      before do
        module Test::TestAdapter
          class Relation < ROM::Relation[:memory]
            schema(:foo_bar) {}
          end
        end
      end

      it "returns name based on dataset" do
        relation = Test::TestAdapter::Relation.new([])

        expect(relation.name).to eql(ROM::Relation::Name[:relation, :foo_bar])
      end
    end

    context "invalid names" do
      let(:relation_name_symbol) do
        module Test
          class Relations < ROM::Relation[:memory]
            schema(:relations) {}
          end
        end
      end

      let(:relation_name_schema) do
        module Test
          class Relations < ROM::Relation[:memory]
            schema(:schema) {}
          end
        end
      end

      it "raises an exception when is symbol" do
        pending "TODO: restore proper validation of relation ids"

        expect {
          relation_name_symbol
          Test::Relations.new
        }.to raise_error(ROM::InvalidRelationName)
      end

      it "raises an exception when schema name is schema" do
        pending "TODO: restore proper validation of relation ids"

        expect {
          relation_name_schema
          Test::Relations.new
        }.to raise_error(ROM::InvalidRelationName)
      end
    end
  end

  describe "#each" do
    it "yields all objects" do
      result = []

      relation.each do |user|
        result << user
      end

      expect(result).to eql([jane, joe])
    end

    it "returns an enumerator if block is not provided" do
      expect(relation.each).to be_instance_of(Enumerator)
    end
  end

  describe "#to_a" do
    it "materializes relation to an array" do
      expect(relation.to_a).to eql([jane, joe])
    end
  end

  describe "#with" do
    it "returns a new instance with the original dataset and given custom options" do
      pending "TODO: move to spec/compat"

      relation = Class.new(ROM::Relation[:memory]) {
        schema(:users) {}
        option :custom
      }.new([], custom: true)

      custom_opts = {mappers: {custom: -> r { r }}}
      new_relation = relation.with(custom_opts).with(custom: true)

      expect(new_relation.dataset).to be(relation.dataset)
      expect(new_relation.options).to include(custom: true)
      expect(new_relation.mappers.custom).to be_a(Proc)
    end
  end

  describe "#wrap?" do
    it "returns false" do
      expect(relation).to_not be_wrap
    end
  end

  describe "#adapter" do
    it "returns adapter set on the class" do
      expect(relation.adapter).to be(:test)
    end
  end

  describe "#graph?" do
    it "returns false" do
      expect(relation.graph?).to be(false)
    end

    it "returns false when curried" do
      relation = Class.new(ROM::Relation[:memory]) do
        config.component.id = :users

        def by_name(*)
          self
        end
      end.new([])

      expect(relation.by_name.graph?).to be(false)
    end
  end

  describe "#schema" do
    it "returns an empty schema by default" do
      relation = Class.new(ROM::Relation[:memory]) {
        config.component.id = :test_some_relation

        schema {}
      }.new([])

      expect(relation.schema).to be_empty
      expect(relation.schema.inferrer).to eql(ROM::Schema::DEFAULT_INFERRER)
      expect(relation.schema.name).to eql(ROM::Relation::Name[:test_some_relation])
      expect(relation.schema?).to be(false)
    end

    context "when relation has custom attribute class" do
      before do
        module Test
          class Attribute < ROM::Attribute; end

          class Relation < ROM::Relation[:memory]
            config.schema.attr_class = Test::Attribute
          end
        end
      end

      it "define schema with attribute class" do
        relation = Class.new(Test::Relation) do
          config.component.id = :test_some_relation

          schema {}
        end.new([])

        expect(relation.schema.attr_class).to eq Test::Attribute
      end
    end
  end

  describe "#input_schema" do
    it "returns a schema hash type" do
      relation = Class.new(ROM::Relation[:memory]) do
        config.component.id = :users

        schema { attribute :id, ROM::Types::Coercible::Integer }
      end.new([])

      expect(relation.input_schema[id: "1"]).to eql(id: 1)
    end

    it "returns a default input schema" do
      relation = Class.new(ROM::Relation[:memory]) do
        config.component.id = :users

        schema {
          attribute :id, ROM::Types::String
        }
      end.new([])

      tuple = {id: "1"}

      expect(relation.input_schema[tuple]).to eql(id: "1")
    end
  end

  describe "#auto_map?" do
    it "returns true by default" do
      relation = ROM::Relation.new

      expect(relation).to be_auto_map
    end

    it "returns false when auto_map is disabled" do
      relation = ROM::Relation.new([], auto_map: false)

      expect(relation).not_to be_auto_map
    end
  end

  describe "#auto_struct?" do
    it "returns false by default" do
      relation = ROM::Relation.new

      expect(relation).not_to be_auto_struct
    end

    it "returns true when auto_struct is enabled" do
      relation = ROM::Relation.new(auto_struct: true)

      expect(relation).to be_auto_struct
    end
  end
end
