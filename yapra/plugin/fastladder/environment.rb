require 'yapra/plugin/base'

module Yapra::Plugin::Fastladder
  class Environment < Yapra::Plugin::Base
    def run(data)
      Yapra::Plugin::Fastladder.const_set :FASTLADDER_ROOT, config['fastladder_root']
      $: << File.join(FASTLADDER_ROOT, 'lib')
      ENV['RAILS_ENV'] = config['rails_env'] || 'development'
      require File.join(FASTLADDER_ROOT, 'config', 'environment')
      data
    end
  end
end
