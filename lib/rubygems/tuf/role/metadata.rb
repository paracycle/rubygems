require 'json'

require 'rubygems/tuf/file'

module Gem::TUF
  module Role
    class Metadata
      DEFAULT_EXPIRY = 86400 # 1 day

      def self.empty(expires_in = DEFAULT_EXPIRY, now = Time.now)
        new({
              "ts"      => now.utc.to_s,
              "expires" => (now.utc + expires_in).to_s,
            })
      end

      def initialize(source)
        @source = source
      end

      def replace(file)
        role_metadata[file.path] = file.to_hash
      end

      def role_metadata
        source['meta'] ||= {}
      end

      def to_hash
        {
          '_type' => type,
          'version' => 2
        }.merge(source)
      end

      def type
        self.class.name.split('::').last
      end

      attr_reader :source, :bucket

      def unwrap_role(content)
        signer.unwrap(content, self.to_hash)
      end

      protected

      def signer
        Gem::TUF::Signer
      end
    end

    class Timestamp < Metadata
    end

    class Release < Metadata
    end
  end
end
