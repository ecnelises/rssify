require 'rss'
require_relative 'zhihu'

fetchers = {
  'zhihu' => ZhihuFetcher,
}

abort 'No source provided, abort.' if ARGV.empty?

fetcher_t = fetchers[ARGV.first]
abort "Unknown source type: #{ARGV.first}" unless fetcher_t
fetcher = feacher_t.new(*ARGV[1..-1])
fetcher.get_items
# TODO: Output RSS text
