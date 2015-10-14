source 'https://rubygems.org'

gemspec

gem 'rom', github: 'rom-rb/rom', branch: 'master'
gem 'rom-sql', github: 'rom-rb/rom-sql', branch: 'master'
gem 'rom-support', github: 'rom-rb/rom-support', branch: 'master'

gem 'inflecto'

group :test do
  gem 'anima', '~> 0.2.0'
  gem 'rspec'
  gem 'byebug', platforms: :mri
  gem 'pg', platforms: [:mri, :rbx]
  gem 'pg_jruby', platforms: :jruby
  gem "codeclimate-test-reporter", require: nil
end

gem 'benchmark-ips'
