require 'digest/sha2'

module Gem::TUF
  class File
    def self.from_body(path, body)
      new(path, body)
    end

    def initialize(path, body)
      @path     = path
      self.body = body
    end

    def to_hash
      {
        'hashes' => { Gem::TUF::HASH_ALGORITHM_NAME => @hash },
        'length' => @length,
      }
    end

    def path_with_hash
      return path if hash.nil?

      ext  = ::File.extname(path)
      dir  = ::File.dirname(path)
      base = ::File.basename(path, ext)

      ::File.join(dir, base + '.' + hash + ext)
    end

    def body=(_body)
      return if _body.nil?

      hash   = Gem::TUF::HASH_ALGORITHM.hexdigest(_body)
      length = _body.bytesize

      if self.length.nil?
        @length = length
      else
        raise "Invalid length for #{path}. Expected #{length}, got #{file.length}" unless self.length == length
      end

      if self.hash.nil?
        @hash = hash
      else
        raise "Invalid hash for #{path}" unless self.hash == hash
      end

      @body = _body
    end

    attr_reader :path, :body, :length, :hash
  end

  class RemoteFile < File
    def initialize(path, bucket, metadata = nil)
      super(path, nil)

      @metadata = metadata

      unless metadata.nil?
        @hash   = metadata.fetch('hashes').fetch(Gem::TUF::HASH_ALGORITHM_NAME)
        @length = metadata.fetch('length')
      end

      fetch(bucket)
    end

    def fetch(bucket)
      @body = bucket.get(path_with_hash)
    end

    attr_reader :parent_role
  end
end
