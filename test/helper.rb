$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "active_record"
require "dry_eraser"
DryEraser::Railtie.run_initializers

require "fileutils"
FileUtils.rm_rf("tmp/test.sqlite3")
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: "tmp/test.sqlite3")

require_relative "fixtures"

class TLDR
  def teardown
    ActiveRecord::Base.connection_pool.release_connection
  end
end
