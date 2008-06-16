require 'yapra/plugin/fastladder/base'

module Yapra::Plugin::Fastladder
  class Fetch < Yapra::Plugin::Fastladder::Base
    def run(data)
      fl_init

      $: << File.join(config['path'], 'lib')
      require 'fastladder'
      $:.pop
      Fastladder::Initializer.run do |config|
      end

      redirect_limit = config['redirect_limit'] || 3

      data.map! do |target|
        case target
        when Feed
          feed = target
        when String, URI
          feed = Feed.find(:first, :conditions => ['feedlink = ?', target.to_s])
        end

        redirect_limit.times do
          should_retry = false
          logger.info "fetch: #{feed.feedlink}"
          response = Fastladder::fetch(feed.feedlink, :modified_on => feed.modified_on)
          logger.info "HTTP status: [#{response.code}] #{feed.feedlink}"
          case response
          when Net::HTTPNotModified
            # nothing to do
          when Net::HTTPSuccess
            p response['last-modified']
            feed.modified_on = Time.rfc2822(response['last-modified']) if response['last-modified']
            feed.source = response.body
          when Net::HTTPRedirection
            logger.info "Redirect: #{feed.feedlink} => #{response['location']}"
            feed.feedlink = response['location']
            feed.modified_on = nil
            feed.save
            should_retry = true
          else #when Net::HTTPClientError, Net::HTTPServerError
            logger.error "Error: #{response.code} #{response.message}"
          end
          feed.crawl_status.update_attribute(:http_status, response.code)
          break unless should_retry
        end if feed
        
        feed
      end

      data.compact!
      data
    end
  end
end
