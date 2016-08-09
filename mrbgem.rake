MRuby::Gem::Specification.new('mruby-websockets') do |spec|
  spec.license = 'Apache-2'
  spec.author  = 'Hendrik Beskow'
  spec.summary = 'WebSocket Client and Server'
  spec.add_dependency 'mruby-socket'
  spec.add_dependency 'mruby-phr'
  spec.add_dependency 'mruby-wslay'
  spec.add_dependency 'mruby-poll'
  spec.add_dependency 'mruby-tls'
  spec.add_dependency 'mruby-sysrandom'
  spec.add_dependency 'mruby-b64'
  spec.add_dependency 'mruby-secure-compare'
end
