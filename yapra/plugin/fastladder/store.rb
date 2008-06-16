require 'yapra/plugin/fastladder/base'
require 'digest/sha1'

module Yapra::Plugin::Fastladder
  class Store < Yapra::Plugin::Fastladder::Base
    def run(data)
      fl_init
      items_limit = config['items_limit'] || 500

      data.each do |feed|
        next unless feed && feed.parsed

        logger.info "parsed: [#{feed.parsed.items.size} items] #{feed.feedlink}"
        items = feed.parsed.items.map { |item|
          Item.new({
            :feed_id => feed.id,
            :link => item.urls.first || "",
            :title => item.title || "",
            :body => item.content,
            :author => item.authors.first,
            :category => item.categories.first,
            :digest => item_digest(item),
            :enclosure => nil,
            :enclosure_type => nil,
            :stored_on => Time.now,
            :modified_on => item.date_published ? item.date_published.to_datetime : nil,
          })
        }

        if items.size > items_limit
          logger.info "too large feed: #{feed.feedlink}(#{feed.items.size})"
          items = items[0, items_limit]
        end

        items = items.reject { |item| feed.items.exists?(["link = ? and digest = ?", item.link, item.digest]) }

        if items.size > items_limit / 2
          logger.info "delete all items: #{feed.feedlink}"
          Item.delete_all(["feed_id = ?", feed.id])
        end

        updated = false
        items.reverse_each do |item|
          if old_item = feed.items.find_by_link(item.link)
            old_item.increment(:version)
            unless almost_same(old_item.title, item.title) and almost_same((old_item.body || "").html2text, (item.body || "").html2text)
              old_item.stored_on = item.stored_on
              updated = true
            end
            %w(title body author category enclosure enclosure_type digest stored_on modified_on).each do |col|
              old_item.send("#{col}=", item.send(col))
            end
            old_item.save
          else
            feed.items << item
            updated = true
          end
        end
        
        if updated
          if last_item = feed.items.find(:first, :order => "created_on DESC")
            feed.modified_on = last_item.created_on
          end
          Subscription.update_all(["has_unread = ?", true], ["feed_id = ?", feed.id])
        end

        feed.update_feedinfo
        feed.crawl_status.update_attribute(:status, 1)
      end

      []
    end

    def item_digest(item)
      str = "#{item.title}#{item.content}"
      str = str.gsub(%r{<br clear="all"\s*/>\s*<a href="http://rss\.rssad\.jp/(.*?)</a>\s*<br\s*/>}im, "")
      str = str.gsub(/\s+/, "")
      Digest::SHA1.hexdigest(str)
    end
  end
end
