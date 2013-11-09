lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'imp'

Gem::Specification.new do |spec|
  spec.name = 'imp'
  spec.summary = 'A lightweight console based password mangement system.'
  spec.description = "
IMP is a simple console password manager. Passwords are stored in an AES
encrypted filesystem-like tree. The main functionality includes printing,
setting and copying passwords, allowing the handling of passwords without
them being shown on screen."
  spec.description
  spec.version = Imp::VERSION
  spec.date = Time.now.strftime('%Y-%m-%d')
  spec.author = 'Thomas Kerber'
  spec.email = 't.kerber@online.de'
  spec.homepage = 'https://github.com/tkerber/imp'
  spec.files = Dir.glob("{docs,bin,lib}/**/*") + ['LICENSE', 'README.md',
    __FILE__]
  spec.executables = ['imp']
  spec.license = "Apache-2.0"
  
  spec.add_runtime_dependency 'highline'
  spec.add_runtime_dependency 'clipboard'
end
