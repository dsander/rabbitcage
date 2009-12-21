require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "rabbitcage"
    gem.summary = %Q{A AMQP firewall which allows to restrict user access to RabbitMQ using ACLs.}
    gem.description = %Q{RabbitMQ's access control capabilities are rather limited. RabbitCage enables fine-grained permission setups, you define which user can perform which AMQP method on which class.}
    gem.email = "git@dsander.de"
    gem.homepage = "http://github.com/dsander/rabbitcage"
    gem.authors = ["Dominik Sander"]
    gem.add_development_dependency "bacon", ">= 0"
    gem.add_dependency "amqp", ">= 0.6.5"
    gem.add_dependency "eventmachine", ">= 0.12.10"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |spec|
    spec.libs << 'spec'
    spec.pattern = 'spec/**/*_spec.rb'
    spec.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :spec => :check_dependencies

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "rabbitcage #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
