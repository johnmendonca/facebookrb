# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{facebookrb}
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Mendonca"]
  s.date = %q{2010-02-05}
  s.email = %q{joaosinho@gmail.com}
  s.extra_rdoc_files = ["README.rdoc"]
  s.files = ["README.rdoc", "Rakefile", "lib/facebookrb.rb"]
  s.homepage = %q{http://github.com/johnmendonca/facebookrb}
  s.rdoc_options = ["--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{facebookrb}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Simple Facebook API client and middleware}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<yajl-ruby>, [">= 0"])
    else
      s.add_dependency(%q<yajl-ruby>, [">= 0"])
    end
  else
    s.add_dependency(%q<yajl-ruby>, [">= 0"])
  end
end
