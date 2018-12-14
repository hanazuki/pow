source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

gemspec

if File.exist?(gemfile_local = File.join(__dir__, 'Gemfile.local'))
  instance_eval File.read(gemfile_local)
end
