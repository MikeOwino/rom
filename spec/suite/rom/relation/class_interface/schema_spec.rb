# frozen_string_literal: true

require "rom/memory"

RSpec.describe ROM::Relation, ".schema" do
  it "defines a canonical schema for a relation" do
    class Test::Users < ROM::Relation[:memory]
      schema do
        attribute :id, Types::Integer.meta(primary_key: true)
        attribute :name, Types::String
        attribute :admin, Types::Bool
      end
    end

    relation_name = ROM::Relation::Name[:users]

    schema = ROM::Memory::Schema.define(
      ROM::Relation::Name.new(:users),
      attributes: [
        {type: ROM::Memory::Types::Integer.meta(primary_key: true, source: relation_name),
         options: {name: :id}},
        {type: ROM::Memory::Types::String.meta(source: relation_name),
         options: {name: :name}},
        {type: ROM::Memory::Types::Bool.meta(source: relation_name),
         options: {name: :admin}}
      ]
    ).finalize_attributes!

    expect(schema.primary_key).to eql([schema[:id]])
    expect(schema.primary_key_name).to be(:id)
    expect(schema.primary_key_names).to eql([:id])

    expect(schema).to eql(schema)

    expect(schema.relations).to be_empty
  end

  it "allows defining types for reading tuples" do
    module Test
      module Types
        CoercibleDate = ROM::Types::Date.constructor(Date.method(:parse))
      end
    end

    class Test::Users < ROM::Relation[:memory]
      schema do
        attribute :id, Types::Integer
        attribute :date, Types::Coercible::String, read: Test::Types::CoercibleDate
      end
    end

    schema = Test::Users.new([]).schema

    expect(schema.to_output_hash)
      .to eql(ROM::Schema::HASH_SCHEMA.schema(id: schema[:id].type, date: schema[:date].meta[:read]))
  end

  it "allows setting composite primary key using `primary_key` macro" do
    class Test::Users < ROM::Relation[:memory]
      schema do
        attribute :name, Types::String
        attribute :email, Types::String

        primary_key :name, :email
      end
    end

    schema = Test::Users.new([]).schema

    expect(schema.primary_key).to eql([schema[:name], schema[:email]])
  end

  it "allows setting composite primary key using attribute options" do
    class Test::Users < ROM::Relation[:memory]
      schema do
        attribute :name, Types::String, primary_key: true
        attribute :email, Types::String
      end
    end

    schema = Test::Users.new([]).schema

    expect(schema.primary_key).to eql([schema[:name]])
  end

  it "allows setting foreign keys using Types::ForeignKey" do
    class Test::Posts < ROM::Relation[:memory]
      schema do
        attribute :author_id, Types::ForeignKey(:users)
        attribute :title, Types::String
      end
    end

    schema = Test::Posts.new([]).schema

    expect(schema[:author_id].primitive).to be(Integer)

    expect(schema.foreign_key(:users)).to be(schema[:author_id])
  end

  it "allows setting foreign keys using attribute options" do
    class Test::Posts < ROM::Relation[:memory]
      schema do
        attribute :author_id, Types::Integer, foreign_key: true, target: :users
        attribute :title, Types::String
      end
    end

    schema = Test::Posts.new([]).schema

    expect(schema[:author_id].primitive).to be(Integer)

    expect(schema.foreign_key(:users)).to be(schema[:author_id])
  end

  it "allows setting attribute options" do
    class Test::Users < ROM::Relation[:memory]
      schema do
        attribute :name, Types::String, alias: :username
      end
    end

    schema = Test::Users.new([]).schema

    expect(schema[:name].alias).to be(:username)
  end

  it "allows setting attribute options while still leaving type undefined" do
    pending "TODO: something's wrong with inferrer now"

    class Test::Users < ROM::Relation[:memory]
      schema do
        attribute :name, alias: :username
      end
    end

    schema = Test::Users.new([]).schema

    expect(schema[:name].alias).to be(:username)
    expect(schema[:name].type).to be_nil
  end

  it "allows JSON read/write coersion", aggregate_failures: true do
    class Test::Posts < ROM::Relation[:memory]
      schema do
        attribute :payload, Types::Coercible::JSON
      end
    end

    schema = Test::Posts.new([]).schema

    json_payload = '{"foo":"bar"}'
    hash_payload = {"foo" => "bar"}

    expect(schema[:payload][hash_payload]).to eq(json_payload)
    expect(schema[:payload].meta[:read][json_payload]).to eq(hash_payload)
  end

  it "allows JSON read/write coersion using symbols", aggregate_failures: true do
    class Test::Posts < ROM::Relation[:memory]
      schema do
        attribute :payload, Types::Coercible::JSON(symbol_keys: true)
      end
    end

    schema = Test::Posts.new([]).schema

    json_payload = '{"foo":"bar"}'
    hash_payload = {foo: "bar"}

    expect(schema[:payload][hash_payload]).to eq(json_payload)
    expect(schema[:payload].meta[:read][json_payload]).to eq(hash_payload)
  end

  it "allows JSON read/write coersion", aggregate_failures: true do
    class Test::Posts < ROM::Relation[:memory]
      schema do
        attribute :payload, Types::Coercible::JSON
      end
    end

    schema = Test::Posts.new([]).schema

    json_payload = '{"foo":"bar"}'
    hash_payload = {"foo" => "bar"}

    expect(schema[:payload][hash_payload]).to eq(json_payload)
    expect(schema[:payload].meta[:read][json_payload]).to eq(hash_payload)
  end

  it "allows JSON to Hash coersion only" do
    class Test::Posts < ROM::Relation[:memory]
      schema do
        attribute :payload, Types::Coercible::JSONHash
      end
    end

    schema = Test::Posts.new([]).schema

    json_payload = '{"foo":"bar"}'
    hash_payload = {"foo" => "bar"}

    expect(schema[:payload][json_payload]).to eq(hash_payload)
  end

  it "returns original payload in JSON to Hash coersion when json is invalid" do
    class Test::Posts < ROM::Relation[:memory]
      schema do
        attribute :payload, Types::Coercible::JSONHash
      end
    end

    schema = Test::Posts.new([]).schema

    json_payload = "invalid: json"

    expect(schema[:payload][json_payload]).to eq(json_payload)
  end

  it "allows JSON to Hash coersion only using symbols as keys" do
    class Test::Posts < ROM::Relation[:memory]
      schema do
        attribute :payload, Types::Coercible::JSONHash(symbol_keys: true)
      end
    end

    schema = Test::Posts.new([]).schema

    json_payload = '{"foo":"bar"}'
    hash_payload = {foo: "bar"}

    expect(schema[:payload][json_payload]).to eq(hash_payload)
  end

  it "allows Hash to JSON coersion only" do
    class Test::Posts < ROM::Relation[:memory]
      schema do
        attribute :payload, Types::Coercible::HashJSON
      end
    end

    schema = Test::Posts.new([]).schema

    json_payload = '{"foo":"bar"}'
    hash_payload = {"foo" => "bar"}

    expect(schema[:payload][hash_payload]).to eq(json_payload)
  end

  it "sets register_as and dataset" do
    class Test::Users < ROM::Relation[:memory]
      schema(:users) do
        attribute :id, Types::Integer
        attribute :name, Types::String
      end
    end

    expect(Test::Users.new([]).name.dataset).to be(:users)
    expect(Test::Users.new([]).name.relation).to be(:users)
  end

  it "sets dataset and respects custom register_as" do
    class Test::Users < ROM::Relation[:memory]
      schema(:users, as: :test_users) do
        attribute :id, Types::Integer
        attribute :name, Types::String
      end
    end

    expect(Test::Users.new([]).name.dataset).to be(:users)
    expect(Test::Users.new([]).name.relation).to be(:test_users)
  end

  it "raises error when schema.constant is missing" do
    pending "TODO: restore validation of schema settings"

    class Test::Users < ROM::Relation[:memory]
      config.schema.constant = nil
    end

    expect { Test::Users.schema(:test) {} }
      .to raise_error(ROM::ConfigError, "Test::Users failed to infer schema.constant setting")
  end

  describe "#schema" do
    it "returns defined schema" do
      class Test::Users < ROM::Relation[:memory]
        config.component.id = :users

        schema do
          attribute :id, Types::Integer.meta(primary_key: true)
          attribute :name, Types::String
          attribute :admin, Types::Bool
        end
      end

      users = Test::Users.new([])

      expect(users.schema).to be_instance_of(Test::Users.config.schema.constant)
    end

    it "raises an error on double definition" do
      expect {
        class Test::Users < ROM::Relation[:memory]
          schema do
            attribute :id, Types::Integer.meta(primary_key: true)
            attribute :name, Types::String
            attribute :id, Types::Integer
          end
        end
      }.to raise_error(ROM::AttributeAlreadyDefinedError, /:id already defined/)
    end

    it "builds optional read types automatically" do
      module Test
        CoercibleString = ROM::Types::String.constructor(:to_s.to_proc)

        class Users < ROM::Relation[:memory]
          schema do
            attribute :id, Types::Integer.meta(primary_key: true)
            attribute :name, Types::String.optional.meta(read: CoercibleString)
          end
        end
      end

      relation = Test::Users.new([])
      schema = relation.schema

      expect(schema[:name].type)
        .to eql(
          Types::String.optional.meta(
            source: relation.name,
            read: Test::CoercibleString.optional
          )
        )
    end
  end

  describe "#schema" do
    it "is idempotent" do
      class Test::Users < ROM::Relation[:memory]
        schema do
          attribute :id, Types::Integer.meta(primary_key: true)
          attribute :name, Types::String
          attribute :admin, Types::Bool
        end
      end

      expect(Test::Users.new([]).schema).to eql(Test::Users.new([]).schema)
    end

    context "custom inflector" do
      let(:inflector) do
        Dry::Inflector.new do |i|
          i.plural("article", "posts")
        end
      end

      it "accepts a custom inflector" do
        pending "TODO: this needs configuration.inflector now"

        class Test::Users < ROM::Relation[:memory]
          schema do
            attribute :id, Types::Integer.meta(primary_key: true)
            attribute :name, Types::String
            attribute :admin, Types::Bool
          end

          associations do
            has_one :article
          end
        end

        schema = Test::Users.new([], inflector: inflector).schema
        association = schema.associations[:article]

        expect(association.target.relation).to eql(:posts)
      end
    end
  end

  describe "#with" do
    it "resets input and output schemas" do
      class Test::Users < ROM::Relation[:memory]
        schema do
          attribute :id, Types::Integer.meta(primary_key: true), read: Types::Integer
          attribute :name, Types::String
        end
      end

      users = Test::Users.new([])
      projected = users.with(schema: users.schema.project(:id))

      expect(projected.input_schema.(id: 1, name: "Jane")).to eql(id: 1)
      expect(projected.output_schema.(id: 1, name: "Jane")).to eql(id: 1)
    end
  end
end
