require 'rubygems/tuf'

class Gem::TUF::MetadataStore
  def initialize(root_path = 'root.txt')
    @root_path = root_path
    @store     = { 'root' => root }
  end

  def bootstrap
    # Fetch timestamp if not valid
    timestamp = fetch('timestamp')
    # TODO: Validate - Offload to the Timestamp role?

    # Fetch release pointed to by timestamp
    release = fetch('release')
    # TODO: Validate - Offload to the Release role?

    # Fetch root. Replace root if changed
    root = fetch('root')
    # TODO: Validate - Offload to the Root role?

    # Fetch targets
    targets = fetch('targets')
    # TODO: Validate - Offload to the Targets role?
  end

  def target(target_path)
    metadata = find_metadata target_path, 'targets'

    if metadata
      file = Gem::TUF::RemoteFile.new(target_path, bucket, metadata.to_hash)
      file.body
    else
      puts "no metadata for #{target_path}"
      ""
    end
  end

  def find_metadata(path, current_role, delegator_role = 'release')
    current = fetch(current_role, delegator_role)

    if current.files[path]
      current.files[path]
    else
      current.delegations.each do |role|
        role_name = role.fetch('name')
        x = find_metadata(path, role_name, current_role)
        return x if x
      end
      nil
    end
  end

  def fetch(role_name, delegator_name = 'root')
    return role(role_name) if role?(role_name)

    delegator = role(delegator_name)
    path = path(role_name)
    metadata = metadata(role_name)

    file = Gem::TUF::RemoteFile.new(path, bucket, metadata)

    signed_hash = JSON.parse(file.body)
    hash = delegator.unwrap_role(signed_hash)

    add_role(role_name, Gem::TUF::Role.from_hash(hash))
  end

  def metadata_role(role)
    case role
    when 'timestamp' then 'root'
    when 'release' then 'timestamp'
    else 'release'
    end
  end

  def metadata(role)
    metadata = role(metadata_role(role))

    unless metadata.nil?
      metadata = metadata.to_hash
      unless metadata['meta'].nil?
        metadata['meta'].fetch(path(role))
      end
    end
  end

  def path(role)
    "metadata/#{role}.txt"
  end

  def add_role(role_name, role)
    store[role_name] = role
  end

  def role(name)
    store[name]
  end

  def role?(name)
    # TODO: Check freshness and validity
    !!store[name]
  end

  def root
    root = File.read(root_path) || raise("Can't find #{root_path}")
    hash = JSON.parse(root)
    signed = Gem::TUF::Signer.unwrap_unsafe(hash)
    Gem::TUF::Role::Root.new(signed)
  end

  attr_reader :store, :root_path
  attr_accessor :bucket
end
