require 'yapra/plugin/fastladder/base'

module Yapra::Plugin::Fastladder
  class CrawlTarget < Yapra::Plugin::Fastladder::Base
    def run(data)
      fl_init
      CrawlStatus.update_all("status = #{CRAWL_OK}", ['crawled_on < ?', 24.hours.ago])
      feeds = nil
      CrawlStatus.transaction {
        conditions = [<<-SQL, CRAWL_OK, 30.minutes.ago]
          crawl_statuses.status = ?
          AND feeds.subscribers_count > 0
          AND (crawl_statuses.crawled_on is NULL OR crawl_statuses.crawled_on < ?)
        SQL
        feeds = Feed.find(:all,
                          :conditions => conditions,
                          :order => 'crawl_statuses.crawled_on ASC',
                          :include => :crawl_status)
        feeds.each { |f| f.crawl_status.update_attributes(:status => CRAWL_NOW, :crawled_on => Time.now) }
      }
      feeds
    end
  end
end
