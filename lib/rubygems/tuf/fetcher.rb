require 'rubygems/tuf'
# TODO: Move this code in here
# $LOAD_PATH.unshift(File.expand_path("~/Code/os/rubygems.org/app/models"))

require 'rubygems/tuf/metadata_store'

class DelegatingBucket
  def initialize(fetcher)
    @fetcher     = fetcher
   end

  def get(path, opts = {})
    # TODO: options & caching
    @fetcher.call(path)
  end

  def create(*)
    raise "Not supported, this is a read-only bucket."
   end
end

class Gem::TUF::Fetcher < Gem::RemoteFetcher
  def initialize(proxy=nil, dns=Resolv::DNS.new)
    super
    @store = Gem::TUF::MetadataStore.new
  end

  def fetch_path(uri, mtime = nil, head = false)
    fetcher = Proc.new do |path|
                super(uri_for_path(uri, path), nil, nil)
              end

    @store.bucket = DelegatingBucket.new(fetcher)

    @store.bootstrap

    @store.target(uri.path[1..-1])
  end

  private

  def uri_for_path(uri, path)
    uri = uri.dup
    puts uri.path[1..-1]
    uri.path = '/' + path
    uri
  end
end
