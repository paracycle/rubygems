$LOAD_PATH << File.expand_path("../../lib", __FILE__)

require 'openssl'
require 'json'
require 'rubygems/util/canonical_json'
require 'rubygems/tuf'
require 'time'

ROLE_NAMES = %w[root targets timestamp release mirrors]
TARGET_ROLES = %w[targets/claimed targets/recently-claimed targets/unclaimed]

def make_key_pair role_name
  private_key_file = "test/rubygems/tuf/#{role_name.gsub('/', '-')}-private.pem"
  public_key_file  = "test/rubygems/tuf/#{role_name.gsub('/', '-')}-public.pem"

  if File.exists? private_key_file
    # Read the existing private key from file
    key = Gem::TUF::KEY_ALGORITHM.new(File.read(private_key_file))
  else
    # Generate a new private key and write to file
    key = Gem::TUF::KEY_ALGORITHM.new(2048,65537) unless key
    File.write private_key_file, key.to_pem
  end

  # Always overwrite the public_key file in case it does not
  # match the private_key we have. This should write out the same
  # data if the public_key is already correct.
  File.write public_key_file, key.public_key.to_pem

  key
end

def deserialize_role_key role_name
  Gem::TUF::KEY_ALGORITHM.new File.read "test/rubygems/tuf/#{role_name.gsub('/', '-')}-private.pem"
end

def key_id key
  Digest::SHA256.hexdigest CanonicalJSON.dump(key_to_hash(key).to_json)
end

def key_to_hash key
  key_hash = {}
  key_hash["keytype"] = "rsa"
  key_hash["keyval"] = {}
  key_hash["keyval"]["private"] = ""
  key_hash["keyval"]["public"] = key.public_key.to_pem
  key_hash
end

class Role

  def initialize(keyids, name=nil, paths=nil, threshold=1)
    @name = name
    @keyids = keyids
    @paths = paths
    @threshold = threshold
  end

  def metadata
    result = { "keyids" => @keyids, "threshold" => @threshold }
    result["paths"] = @paths unless @paths.nil?
    result["name"] = @name unless @name.nil?
    result
  end
end

def write_signed_metadata(role, metadata)
  rsa_key = deserialize_role_key(role)
  key = Gem::TUF::Key.private_key(rsa_key)
  signed_content = Gem::TUF::Signer.sign({"signed" => metadata}, key)
  File.write("test/rubygems/tuf/#{role}.txt", JSON.pretty_generate(signed_content))
end

def role_metadata key
  { "keyids" => [key.id], "threshold" => 1}
end

def generate_test_root
  metadata = {}
  role_keys = {}
  public_keys = {}
  ROLE_NAMES.each do |role|
    private_role_key = make_key_pair role
    public_role_key = Gem::TUF::Key.public_key(private_role_key.public_key)

    role_keys[role] = private_role_key
    metadata[role] = role_metadata public_role_key
    public_keys[public_role_key.id] = public_role_key.to_hash
  end

  root = {
    "_type"   => "Root",
    "ts"      =>  Time.now.utc.to_s,
    "expires" => (Time.now.utc + 10000).to_s, # TODO: There is a recommend value in pec
    "keys"    => public_keys,
    "roles"   => metadata,
      # TODO: Once delegated targets are operational, the root
      # targets.txt should use an offline key.
  }

  write_signed_metadata("root", root)
end

def generate_test_targets
  # TODO: multiple target files

  roles = {}
  keys = {}

  TARGET_ROLES.each do |role|
    key = make_key_pair role
    key_digest = key_id key
    keys[key_digest] = key_to_hash(key)
    roles[role] = Role.new([key_digest], role, [], 1).metadata
  end

  targets = {
    "_type"   => "Targets",
    "ts"      =>  Time.now.utc.to_s,
    "expires" => (Time.now.utc + 10000).to_s, # TODO: There is a recommend value in pec
    "delegations" => {"roles" => roles.values, "keys" => keys},
    "targets" => {}
    }

  write_signed_metadata("targets", targets)
end

def generate_test_timestamp
  release_contents = File.read 'test/rubygems/tuf/release.txt' # TODO
  timestamp = {
    "_type"   => "Timestamp",
    "ts"      =>  Time.now.utc.to_s,
    "expires" => (Time.now.utc + 10000).to_s, # TODO: There is a recommend value in pec
    "meta" => { "release.txt" =>
                { "hashes" => {
                    Gem::TUF::DIGEST_NAME =>
                      Gem::TUF::DIGEST_ALGORITHM.hexdigest(release_contents)
                  },
                  "length" => release_contents.length,
                },
              },
    }

  write_signed_metadata("timestamp", timestamp)
end

def generate_test_release
  root_contents = File.read 'test/rubygems/tuf/root.txt'
  targets_contents = File.read 'test/rubygems/tuf/targets.txt'

  release = {
    "_type"   => "Release",
    "ts"      =>  Time.now.utc.to_s,
    "expires" => (Time.now.utc + 10000).to_s, # TODO: There is a recommend value in pec
    "meta" => { "root.txt" =>
                { "hashes" => {
                    Gem::TUF::DIGEST_NAME =>
                      Gem::TUF::DIGEST_ALGORITHM.hexdigest(root_contents)
                  },
                  "length" => root_contents.length,
                },

                "targets.txt" =>
                { "hashes" => {
                    Gem::TUF::DIGEST_NAME =>
                      Gem::TUF::DIGEST_ALGORITHM.hexdigest(targets_contents)
                  },
                  "length" => targets_contents.length,
                },
              },
    }

  write_signed_metadata("release", release)
end

def generate_test_metadata
  generate_test_root
  generate_test_targets
  generate_test_release
  generate_test_timestamp
end

generate_test_metadata
