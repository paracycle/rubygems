require 'rubygems/test_case'
require 'rubygems/tuf'
require 'rubygems/tuf/metadata_store'

class TestBucket
  def get(path)
    filename = File.basename(path)
    tuf_file = Gem::TestCase.tuf_file(filename)
    File.read(tuf_file)
  end

  def create(*)
    raise "Not implemented"
  end
end

class TestGemTUFMetadataStore < Gem::TestCase
  ROOT_FILE       = tuf_file("root.txt")

  def test_bootstrap
    store = Gem::TUF::MetadataStore.new ROOT_FILE
    store.bucket = TestBucket.new
    store.bootstrap
  end
end
