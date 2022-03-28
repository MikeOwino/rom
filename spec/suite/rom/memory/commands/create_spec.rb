# frozen_string_literal: true

require "spec_helper"

require "rom/memory"

RSpec.describe ROM::Memory::Commands::Create do
  include_context "container"
  include_context "users and tasks"

  before do
    configuration.relation(:users) do
      def by_id(id)
        restrict(id: id)
      end
    end
    configuration.commands(:users) do
      define(:create)
    end
  end

  subject(:command) { container.commands[:users][:create] }

  it_behaves_like "a command"
end
