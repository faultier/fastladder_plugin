require 'yapra/plugin/base'
require 'feed-normalizer'
require 'yaml'
require 'active_record'

module Yapra::Plugin::Fastladder
  CRAWL_OK = 1
  CRAWL_NOW = 10

  class Base < Yapra::Plugin::Base
    def fl_init
      unless config['path'] || config['database']
        raise ArgumentError, "#{self.class} required path to fastladder or database config"
      end
      if config['path']
        path = config['path']
        env  = config['env'] || 'development'
        dbconfig = YAML.load_file(File.join(path, 'config/database.yml'))
        dbconfig[env]['database'] = File.join(path, dbconfig[env]['database']) if dbconfig[env]['adapter'] == 'sqlite3'
        ActiveRecord::Base.establish_connection(dbconfig[env])
      else
        ActiveRecord::Base.establish_connection(config['database'])
      end
    end
  end

  class CrawlStatus < ActiveRecord::Base
    belongs_to :feed
  end

  class Feed < ActiveRecord::Base
    has_one :crawl_status
    has_many :items
    has_many :subscriptions

    attr_accessor :source

    def parsed
      @parsed ||= @source.kind_of?(FeedNormalizer::Feed) ? @source : FeedNormalizer::FeedNormalizer.parse(@source)
    end

    def update_feedinfo
      title = parsed.title
      link  = parsed.url
      description = parsed.description || ""
      save
    end
  end

  class Item < ActiveRecord::Base
    belongs_to :feed
  end

  class Subscription < ActiveRecord::Base
    belongs_to :feed
  end
end
