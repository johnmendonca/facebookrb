# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rack-fb}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Mendonca"]
  s.date = %q{2010-01-16}
  s.email = %q{joaosinho@gmail.com}
  s.extra_rdoc_files = ["README.markdown"]
  s.files = ["README.markdown", "Rakefile", "spec", "lib/rack", "lib/rack/facebook.rb", "lib/mini_fb.rb"]
  s.homepage = %q{http://github.com/johnmendonca/rack-fb}
  s.rdoc_options = ["--main", "README.markdown"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{rack-fb}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Facebook middleware and API client}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rack>, ["~> 1.0.1"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
    else
      s.add_dependency(%q<rack>, ["~> 1.0.1"])
      s.add_dependency(%q<rspec>, [">= 0"])
    end
  else
    s.add_dependency(%q<rack>, ["~> 1.0.1"])
    s.add_dependency(%q<rspec>, [">= 0"])
  end
end
