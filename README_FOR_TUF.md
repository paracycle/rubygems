Tuf
===

This fork contains an implementation of The Update Framework (TUF).

It requires the server to be running the `tuf-xavier` branch from https://github.com/square/rubygems.org

* Set up the server as described in its README, including pushing a gem.
* Copy `config/root.txt` from the server to the rubygems root directory.

Then install a gem:

    ruby -S --disable-gems bin/gem install --tuf \
      --clear-sources --source http://localhost:3000 \
      yourgem


## Tests
----

In order to run tests, you currently need to generate test metadata by hand, using a script.

Just run the script:

    ruby -rubygems -Ilib util/create_tuf_metadata.rb

and the metadata files will be ready waiting for you in `test/rubygems/tuf` folder.