=begin rdoc
  Simply a stub class for documentation purposes
  Plugins are all resources
=end
module PoolParty
  class Plugin
  end
end

%w(apache git rails).each do |plugin|
  require "plugins/#{plugin}"
end