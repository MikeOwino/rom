# frozen_string_literal: true

RSpec.describe "Using changesets" do
  include_context "changeset / database"
  include_context "changeset / relations"

  before do
    module Test
      class User < Dry::Struct
        attribute :id, Dry::Types["strict.integer"]
        attribute :name, Dry::Types["strict.string"]
      end
    end

    configuration.mappers do
      define(:users) do
        model Test::User
        config.component.id = :user
      end
    end
  end

  describe "Create" do
    it "sets empty data only for stateful changesets" do
      create = users.changeset(:create)
      expect(create).to be_empty
      expect(create).to be_kind_of(ROM::Changeset::Create)

      update = users.changeset(:update)
      expect(update).to be_empty
      expect(update).to be_kind_of(ROM::Changeset::Update)

      delete = users.changeset(:delete)
      expect(delete).to be_kind_of(ROM::Changeset::Delete)
    end

    it "works with command plugins" do
      configuration.commands(:books) do
        define(:create) do
          use :timestamps
          timestamp :created_at, :updated_at
          config.result = :one
        end
      end

      changeset = books.changeset(:create, title: "rom-rb is awesome")

      result = changeset.commit

      expect(result.id).to_not be(nil)
      expect(result.title).to eql("rom-rb is awesome")
      expect(result.created_at).to be_instance_of(Time)
      expect(result.updated_at).to be_instance_of(Time)
    end

    it "can be passed to a command" do
      changeset = users.changeset(:create, name: "Jane Doe")
      command = users.command(:create)

      result = command.(changeset)

      expect(result.id).to_not be(nil)
      expect(result.name).to eql("Jane Doe")
    end

    it "can be passed to a command graph" do
      changeset = users.changeset(
        :create,
        name: "Jane Doe", posts: [{title: "Just Do It", alien: "or sutin"}]
      )

      command = users.combine(:posts).command(:create)
      result = command.(changeset)

      expect(result.id).to_not be(nil)
      expect(result.name).to eql("Jane Doe")
      expect(result.posts.size).to be(1)
      expect(result.posts[0].title).to eql("Just Do It")
    end

    it "preprocesses data using changeset pipes" do
      changeset = books.changeset(:create, title: "rom-rb is awesome").map(:add_timestamps)
      command = books.command(:create)
      result = command.(changeset)

      expect(result.id).to_not be(nil)
      expect(result.title).to eql("rom-rb is awesome")
      expect(result.created_at).to be_instance_of(Time)
      expect(result.updated_at).to be_instance_of(Time)
    end

    it "preprocesses data using custom block" do
      changeset = books
        .changeset(:create, title: "rom-rb is awesome")
        .map { |tuple| tuple.merge(created_at: Time.now) }

      command = books.command(:create)
      result = command.(changeset)

      expect(result.id).to_not be(nil)
      expect(result.title).to eql("rom-rb is awesome")
      expect(result.created_at).to be_instance_of(Time)
    end

    it "preprocesses data using built-in steps and custom block" do
      changeset = books
        .changeset(:create, title: "rom-rb is awesome")
        .extend(:touch) { |tuple| tuple.merge(created_at: Time.now) }

      command = books.command(:create)
      result = command.(changeset)

      expect(result.id).to_not be(nil)
      expect(result.title).to eql("rom-rb is awesome")
      expect(result.created_at).to be_instance_of(Time)
      expect(result.updated_at).to be_instance_of(Time)
    end

    it "preprocesses data using map blocks in a custom class" do
      changeset_class = Class.new(ROM::Changeset::Create) do
        map do |tuple|
          extend_tuple(tuple)
        end

        private

        def extend_tuple(tuple)
          tuple.merge(title: tuple[:title] + ", yes really")
        end
      end

      changeset = books.changeset(changeset_class, title: "rom-rb is awesome")
      command = books.command(:create)
      result = command.(changeset)

      expect(result.id).to_not be(nil)
      expect(result.title).to eql("rom-rb is awesome, yes really")

      result = books.changeset(changeset_class, title: "rom-rb is awesome").commit

      expect(result.id).to_not be(nil)
      expect(result.title).to eql("rom-rb is awesome, yes really")
    end

    it "preserves relation mappers with create" do
      changeset = users.map_with(:user).changeset(:create, name: "Joe Dane")

      expect(changeset.commit.to_h).to eql(id: 1, name: "Joe Dane")
    end

    context "combined relations" do
      it "automatically builds associated changeset" do
        pending "Not implemented yet. This feature is scheduled for 6.0"

        data = {name: "Jane Doe", posts: [{title: "Task 1"}, {title: "Task 2"}]}
        changeset = users.combine(:posts).changeset(:create, data)

        result = changeset.commit

        expect(result[:id]).not_to be(nil)
        expect(result[:name]).not_to eql("Jane Doe")
        expect(result[:posts].size).to be(2)

        post_1, post_2 = result[:posts]

        expect(post_1).to include(data[:posts][0])
        expect(post_2).to include(data[:posts][1])
      end
    end
  end

  describe "Update" do
    it "can be passed to a command" do
      book = books.command(:create).call(title: "rom-rb is awesome")

      changeset = books.by_pk(book.id)
        .changeset(:update, title: "rom-rb is awesome for real")
        .extend(:touch)

      expect(changeset.diff).to eql(title: "rom-rb is awesome for real")

      result = changeset.commit

      expect(result.id).to be(book.id)
      expect(result.title).to eql("rom-rb is awesome for real")
      expect(result.updated_at).to be_instance_of(Time)
    end

    it "preprocesses data using map blocks in a custom class" do
      book = books.command(:create).call(title: "rom-rb is awesome")

      changeset_class = Class.new(ROM::Changeset::Update) do
        map do |tuple|
          extend_tuple(tuple)
        end

        private

        def extend_tuple(tuple)
          tuple.merge(title: tuple[:title] + ", yes really")
        end
      end

      result = books.by_pk(book.id)
        .changeset(changeset_class, title: "rom-rb is awesome for real")
        .commit

      expect(result.id).to be(book.id)
      expect(result.title).to eql("rom-rb is awesome for real, yes really")
    end

    it "works with command plugins" do
      configuration.commands(:books) do
        define(:update) do
          use :timestamps
          timestamp :updated_at
          config.result = :one
        end
      end

      book = books.command(:create).call(title: "rom-rb is awesome")

      changeset = books.by_pk(book.id).changeset(:update, title: "rom-rb is awesome for real")

      result = changeset.commit

      expect(result.id).to_not be(nil)
      expect(result.title).to eql("rom-rb is awesome for real")
      expect(result.updated_at).to be_instance_of(Time)
    end

    it "skips update execution with no diff" do
      book = books.command(:create).call(title: "rom-rb is awesome")

      changeset = books
        .by_pk(book.id)
        .changeset(:update, title: "rom-rb is awesome")
        .extend(:touch)

      expect(changeset).to_not be_diff

      result = changeset.commit

      expect(result.id).to be(book.id)
      expect(result.title).to eql("rom-rb is awesome")
      expect(result.updated_at).to be(nil)
    end
  end
end
