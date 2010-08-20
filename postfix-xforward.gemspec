require File.join(File.dirname(__FILE__), 'lib', 'postfix-xforward', 'version')
gemspec = Gem::Specification.new('postfix-xforward', PostfixXForward::Version::STRING) do |s|
  s.summary      = "Net::SMTP extension to support Postfix MTA's XFORWARD SMTP extension."
  s.description  = <<-DESCRIPTION.strip.gsub(/^\s+/, '')
    This extends ruby's Net::SMTP library to support the Postfix MTA's
    XFORWARD SMTP extension.
  DESCRIPTION
  s.authors                   = ['Kendall Gifford']
  s.email                     = ['zettabyte@gmail.com']
  s.homepage                  =  'http://github.com/zettabyte/postfix-xforward'
# s.rubyforge_project         =  'postfix-xforward'
  s.require_path              =  'lib'
  s.required_rubygems_version =  '>= 1.3.6'
  s.files                     = Dir.glob("lib/**/*") + %w{LICENSE README.rdoc CHANGELOG.rdoc}
  s.platform                  = Gem::Platform::RUBY
end
