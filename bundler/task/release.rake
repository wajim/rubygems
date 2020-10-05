# frozen_string_literal: true

require_relative "../lib/bundler/gem_tasks"
require_relative "../spec/support/build_metadata"

Bundler::GemHelper.tag_prefix = "bundler-"

task :build_metadata do
  Spec::BuildMetadata.write_build_metadata
end

namespace :build_metadata do
  task :clean do
    Spec::BuildMetadata.reset_build_metadata
  end
end

task :build => ["build_metadata"] do
  Rake::Task["build_metadata:clean"].tap(&:reenable).real_invoke
end
task "release:rubygem_push" => ["release:verify_docs", "release:verify_github", "build_metadata", "release:github"]

namespace :release do
  task :verify_docs => :"man:check"

  def gh_api_authenticated_request(opts)
    require "netrc"
    require "net/http"
    require "json"
    _username, token = Netrc.read["api.github.com"]

    host = opts.fetch(:host) { "https://api.github.com/" }
    path = opts.fetch(:path)
    uri = URI.join(host, path)
    headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/vnd.github.v3+json",
      "Authorization" => "token #{token}",
    }.merge(opts.fetch(:headers, {}))
    body = opts.fetch(:body) { nil }

    response = if body
      Net::HTTP.post(uri, body.to_json, headers)
    else
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Get.new(uri.request_uri)
      headers.each {|k, v| req[k] = v }
      http.request(req)
    end

    if response.code.to_i >= 400
      raise "#{uri}\n#{response.inspect}\n#{begin
                                              JSON.parse(response.body)
                                            rescue JSON::ParseError
                                              response.body
                                            end}"
    end
    JSON.parse(response.body)
  end

  desc "Make sure github API is ready to be used"
  task :verify_github do
    gh_api_authenticated_request :path => "/user"
  end

  def confirm(prompt = "")
    loop do
      print(prompt)
      print(": ") unless prompt.empty?

      answer = $stdin.gets.strip
      break if answer == "y"
      abort if answer == "n"
    end
  rescue Interrupt
    abort
  end

  def gh_api_request(opts)
    require "net/http"
    require "json"
    host = opts.fetch(:host) { "https://api.github.com/" }
    path = opts.fetch(:path)
    response = Net::HTTP.get_response(URI.join(host, path))

    links = Hash[*(response["Link"] || "").split(", ").map do |link|
      href, name = link.match(/<(.*?)>; rel="(\w+)"/).captures

      [name.to_sym, href]
    end.flatten]

    parsed_response = JSON.parse(response.body)

    if n = links[:next]
      parsed_response.concat gh_api_request(:host => host, :path => n)
    end

    parsed_response
  end

  def release_notes(version)
    title_token = "## "
    current_version_title = "#{title_token}#{version}"
    current_minor_title = "#{title_token}#{version.segments[0, 2].join(".")}"
    text = File.open("CHANGELOG.md", "r:UTF-8", &:read)
    lines = text.split("\n")

    current_version_index = lines.find_index {|line| line.strip =~ /^#{current_version_title}($|\b)/ }
    unless current_version_index
      raise "Update the changelog for the last version (#{version})"
    end
    current_version_index += 1
    previous_version_lines = lines[current_version_index.succ...-1]
    previous_version_index = current_version_index + (
      previous_version_lines.find_index {|line| line.start_with?(title_token) && !line.start_with?(current_minor_title) } ||
      lines.count
    )

    relevant = lines[current_version_index..previous_version_index]

    relevant.join("\n").strip
  end

  desc "Push the release to Github releases"
  task :github, :version do |_t, args|
    version = Gem::Version.new(args.version || Bundler::GemHelper.gemspec.version)
    tag = "bundler-v#{version}"

    gh_api_authenticated_request :path => "/repos/rubygems/rubygems/releases",
                                 :body => {
                                   :tag_name => tag,
                                   :name => tag,
                                   :body => release_notes(version),
                                   :prerelease => version.prerelease?,
                                 }
  end

  desc "Prepare a patch release with the PRs from master in the patch milestone"
  task :prepare_patch, :version do |_t, args|
    version = args.version
    current_version = Bundler::GemHelper.gemspec.version

    version ||= begin
      segments = current_version.segments
      if segments.last.is_a?(String)
        segments << "1"
      else
        segments[-1] += 1
      end
      segments.join(".")
    end

    puts "Cherry-picking PRs milestoned for #{version} (currently #{current_version}) into the stable branch..."

    milestones = gh_api_request(:path => "repos/rubygems/rubygems/milestones?state=open")
    unless patch_milestone = milestones.find {|m| m["title"] == version }
      abort "failed to find #{version} milestone on GitHub"
    end
    prs = gh_api_request(:path => "repos/rubygems/rubygems/issues?milestone=#{patch_milestone["number"]}&state=all")
    prs.map! do |pr|
      abort "#{pr["html_url"]} hasn't been closed yet!" unless pr["state"] == "closed"
      next unless pr["pull_request"]
      pr["number"].to_s
    end
    prs.compact!

    branch = Gem::Version.new(version).segments.map.with_index {|s, i| i == 0 ? s + 1 : s }[0, 2].join(".")
    sh("git", "checkout", "-b", "release_bundler/#{version}", branch)

    commits = `git log --oneline origin/master -- bundler`.split("\n").map {|l| l.split(/\s/, 2) }.reverse
    commits.select! {|_sha, message| message =~ /(Auto merge of|Merge pull request|Merge) ##{Regexp.union(*prs)}/ }

    abort "Could not find commits for all PRs" unless commits.size == prs.size

    if commits.any? && !system("git", "cherry-pick", "-x", "-m", "1", *commits.map(&:first))
      warn "Opening a new shell to fix the cherry-pick errors. Press Ctrl-D when done to resume the task"

      unless system(ENV["SHELL"] || "zsh")
        abort "Failed to resolve conflicts on a different shell. Resolve conflicts manually and finish the task manually"
      end
    end

    version_file = "lib/bundler/version.rb"
    version_contents = File.read(version_file)
    unless version_contents.sub!(/^(\s*VERSION = )"#{Gem::Version::VERSION_PATTERN}"/, "\\1#{version.to_s.dump}")
      abort "failed to update #{version_file}, is it in the expected format?"
    end
    File.open(version_file, "w") {|f| f.write(version_contents) }

    sh("git", "commit", "-am", "Version #{version}")
  end

  desc "Open all PRs that have not been included in a stable release"
  task :open_unreleased_prs do
    def prs(on = "master")
      commits = `git log --oneline origin/#{on} -- bundler`.split("\n")
      commits.reverse_each.map {|c| c =~ /(Auto merge of|Merge pull request|Merge) #(\d+)/ && $2 }.compact
    end

    def minor_release_tags
      `git ls-remote origin`.split("\n").map {|r| r =~ %r{refs/tags/bundler-v([\d.]+)$} && $1 }.compact.map {|v| Gem::Version.create(Gem::Version.create(v).segments[0, 2].join(".")) }.sort.uniq
    end

    def to_stable_branch(release_tag)
      release_tag.segments.map.with_index {|s, i| i == 0 ? s + 1 : s }[0, 2].join(".")
    end

    last_stable = to_stable_branch(minor_release_tags[-1])
    previous_to_last_stable = to_stable_branch(minor_release_tags[-2])

    in_release = prs("HEAD") - prs(last_stable) - prs(previous_to_last_stable)

    n_prs = in_release.size

    print "About to review #{n_prs} pending PRs. "

    confirm "Continue? (y/n)"

    in_release.each.with_index do |pr, idx|
      url_opener = /darwin/ =~ RUBY_PLATFORM ? "open" : "xdg-open"
      url = "https://github.com/rubygems/rubygems/pull/#{pr}"
      print "[#{idx + 1}/#{n_prs}] #{url}. (n)ext/(o)pen? "
      system(url_opener, url, :out => IO::NULL, :err => IO::NULL) if $stdin.gets.strip == "o"
    end
  end
end
