$LOAD_PATH << File.expand_path("../../lib", __FILE__)

require 'openssl'
require 'rubygems/tuf'
require 'time'

ROLE_NAMES = %w[root targets timestamp release mirrors]
TARGET_ROLES = %w[targets/claimed targets/recently-claimed targets/unclaimed]

def make_key_pair role_name
  private_key_file = "test/rubygems/tuf/#{role_name.gsub('/', '-')}-private.pem"
  public_key_file  = "test/rubygems/tuf/#{role_name.gsub('/', '-')}-public.pem"

  if File.exists? private_key_file
    # Read the existing private key from file
    private_key = File.read(private_key_file)
    key = Gem::TUF::Key.private_key(private_key)
  else
    # Generate a new private key and write to file
    key = Gem::TUF::Key.create_key
    File.write private_key_file, key.private
  end

  # Always overwrite the public_key file in case it does not
  # match the private_key we have. This should write out the same
  # data if the public_key is already correct.
  File.write public_key_file, key.public

  key
end

def deserialize_role_key role_name
  File.read "test/rubygems/tuf/#{role_name.gsub('/', '-')}-private.pem"
end

class Role
  def initialize(keyids, threshold=1, name=nil, paths=nil)
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

def metadata_for_roles(roles)
  roles.map do |role|
    ["#{role}.txt", File.read("test/rubygems/tuf/#{role}.txt")]
  end.to_h
end

def write_signed_metadata(role, metadata)
  rsa_key = deserialize_role_key(role)
  key = Gem::TUF::Key.private_key(rsa_key)
  signed_content = Gem::TUF::Signer.sign({"signed" => metadata}, key)
  File.write("test/rubygems/tuf/#{role}.txt", JSON.pretty_generate(signed_content))
end

def generate_test_root
  roles = {}
  keys = {}

  ROLE_NAMES.each do |role|
    key = make_key_pair role
    key_digest = key.id
    keys[key_digest] = key.to_hash
    roles[role] = Role.new([key_digest]).metadata
  end

  root = {
    "_type"   => "Root",
    "ts"      =>  Time.now.utc.to_s,
    "expires" => (Time.now.utc + 10000).to_s, # TODO: There is a recommend value in pec
    "keys"    => keys,
    "roles"   => roles,
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
    key_digest = key.id
    keys[key_digest] = key.to_hash
    roles[role] = Role.new([key_digest], 1, role, []).metadata
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
  metadata  = metadata_for_roles %w(release)

  # TODO: There is a recommend value in spec
  timestamp = Gem::TUF::Role::Timestamp.build(10000, metadata).to_hash

  write_signed_metadata("timestamp", timestamp)
end

def generate_test_release
  metadata = metadata_for_roles %w(root targets)

  # TODO: There is a recommend value in spec
  release = Gem::TUF::Role::Release.build(10000, metadata).to_hash

  write_signed_metadata("release", release)
end

def generate_test_metadata
  generate_test_root
  generate_test_targets
  generate_test_release
  generate_test_timestamp
end

generate_test_metadata
