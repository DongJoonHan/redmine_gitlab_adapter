require 'redmine/scm/adapters/abstract_adapter'
require 'octokit'
require 'uri'
require 'time'
require 'base64'

module Redmine
  module Scm
    module Adapters
      class GithubAdapter < AbstractAdapter
        GITHUB_BIN = 'github'
        GITHUB_DEFAULT_BRANCH_NAMES = %w[main master].freeze
        PER_PAGE = 100

        class GithubBranch < Branch
          attr_accessor :is_default
        end

        class << self
          def client_command
            @@bin ||= GITHUB_BIN
          end

          def sq_bin
            @@sq_bin ||= shell_quote_command
          end

          def client_version
            @@client_version ||= [1, 0]
          end

          def client_available
            true
          end
        end

        def initialize(url, root_url = nil, login = nil, password = nil, path_encoding = nil)
          super
          @repo = extract_repo_path(url, root_url)
          @client = Octokit::Client.new(
            :access_token => password,
            :api_endpoint => normalize_api_endpoint(url, root_url)
          )
        end

        def info
          Info.new(:root_url => root_url, :lastrev => lastrev('', nil))
        rescue
          nil
        end

        def branches
          return @branches if @branches

          default = default_branch_from_repository
          @branches = []

          1.step do |page|
            github_branches = @client.branches(@repo, :page => page, :per_page => PER_PAGE)
            break if github_branches.empty?

            github_branches.each do |github_branch|
              branch = GithubBranch.new(github_branch.name)
              branch.revision = github_branch.commit.sha
              branch.scmid = github_branch.commit.sha
              branch.is_default = (github_branch.name == default)
              @branches << branch
            end
            break if github_branches.length < PER_PAGE
          end

          @branches.sort!
        rescue Octokit::Error
          nil
        end

        def tags
          return @tags if @tags
          @tags = []

          1.step do |page|
            github_tags = @client.tags(@repo, :page => page, :per_page => PER_PAGE)
            break if github_tags.empty?
            github_tags.each do |github_tag|
              @tags << github_tag.name
            end
            break if github_tags.length < PER_PAGE
          end

          @tags
        rescue Octokit::Error
          nil
        end

        def default_branch
          return if branches.blank?

          (
            branches.detect(&:is_default) ||
            branches.detect { |b| GITHUB_DEFAULT_BRANCH_NAMES.include?(b.to_s) } ||
            branches.first
          ).to_s
        end

        def entry(path = nil, identifier = nil)
          parts = path.to_s.split(%r{[\/\\]}).select { |n| !n.blank? }
          search_path = parts[0..-2].join('/')
          search_name = parts[-1]
          if search_path.blank? && search_name.blank?
            Entry.new(:path => '', :kind => 'dir')
          else
            es = entries(search_path, identifier, :report_last_commit => false)
            es ? es.detect { |e| e.name == search_name } : nil
          end
        end

        def entries(path = nil, identifier = nil, options = {})
          path ||= ''
          identifier = default_branch if identifier.nil?
          return nil if identifier.nil?

          request = { :ref => identifier }
          request[:path] = path unless path.blank?
          github_contents = @client.contents(@repo, request)
          github_contents = [github_contents] unless github_contents.is_a?(Array)

          items = Entries.new
          github_contents.each do |content|
            full_path = content.path.to_s
            kind = (content.type == 'dir') ? 'dir' : 'file'
            items << Entry.new(
              :name => content.name.to_s.dup,
              :path => full_path.dup,
              :kind => kind,
              :size => (kind == 'dir') ? nil : content.size,
              :lastrev => options[:report_last_commit] ? lastrev(full_path, identifier) : Revision.new
            )
          end
          items.sort_by_name
        rescue Octokit::Error
          nil
        end

        def lastrev(path, rev)
          return nil if path.nil?
          options = { :per_page => 1 }
          options[:path] = path unless path.blank?
          options[:sha] = rev unless rev.blank?

          github_commits = @client.commits(@repo, options)
          return nil if github_commits.empty?
          commit = github_commits.first

          Revision.new(
            :identifier => commit.sha,
            :scmid => commit.sha,
            :author => commit_author_name(commit),
            :time => commit_time(commit),
            :message => nil,
            :paths => nil
          )
        rescue Octokit::Error
          nil
        end

        def revisions(path, identifier_from, identifier_to, options = {})
          revs = Revisions.new
          per_page = options[:limit] ? options[:limit].to_i : PER_PAGE
          per_page = PER_PAGE if per_page <= 0
          all = options[:all] || false
          since = options[:last_committed_date].to_s

          req = { :per_page => per_page }
          req[:path] = path unless path.blank?
          req[:sha] = identifier_to unless identifier_to.blank?
          req[:since] = since unless since.blank?

          1.step do |page|
            req[:page] = page
            github_commits = @client.commits(@repo, req)
            break if github_commits.empty?

            github_commits.each do |github_commit|
              files = []
              message = commit_message(github_commit)
              parents = Array(github_commit.parents).map { |p| p.sha.to_s }

              if all
                begin
                  detailed_commit = @client.commit(@repo, github_commit.sha)
                  message = commit_message(detailed_commit)
                  parents = Array(detailed_commit.parents).map { |p| p.sha.to_s }
                  Array(detailed_commit.files).each do |file|
                    case file.status
                    when 'added'
                      files << { :action => 'A', :path => file.filename }
                    when 'removed'
                      files << { :action => 'D', :path => file.filename }
                    when 'renamed'
                      files << { :action => 'D', :path => file.previous_filename }
                      files << { :action => 'A', :path => file.filename }
                    else
                      files << { :action => 'M', :path => file.filename }
                    end
                  end
                rescue Octokit::Error
                  files = []
                end
              end

              revision = Revision.new(
                :identifier => github_commit.sha,
                :scmid => github_commit.sha,
                :author => commit_author_name(github_commit),
                :time => commit_time(github_commit),
                :message => message,
                :paths => files,
                :parents => parents
              )
              revs << revision
            end
            break if github_commits.length < per_page
            break unless all
          end

          revs.sort! { |a, b| a.time <=> b.time }
          revs
        rescue Octokit::Error => e
          logger.error("github log error: #{e.message}")
          nil
        end

        def diff(path, identifier_from, identifier_to = nil)
          path ||= ''
          diff = []

          files =
            if identifier_to.nil?
              Array(@client.commit(@repo, identifier_from).files)
            else
              Array(@client.compare(@repo, identifier_to, identifier_from).files)
            end

          files.each do |file|
            next if identifier_to.nil? && path.length > 0 && file.filename != path

            status = file.status.to_s
            new_path = file.filename.to_s
            old_path = file.respond_to?(:previous_filename) ? file.previous_filename.to_s : new_path
            patch = file.respond_to?(:patch) ? file.patch.to_s : ''

            if status == 'renamed'
              diff << 'diff'
              diff << "--- a/#{old_path}"
              diff << "+++ b/#{new_path}"
            elsif status == 'added'
              diff << 'diff'
              diff << '--- /dev/null'
              diff << "+++ b/#{new_path}"
            elsif status == 'removed'
              diff << 'diff'
              diff << "--- a/#{old_path}"
              diff << '+++ /dev/null'
            else
              diff << 'diff'
              diff << "--- a/#{old_path}"
              diff << "+++ b/#{new_path}"
            end

            if patch.blank?
              diff << '@@ -0,0 +0,0 @@'
              diff << 'Binary files differ'
            else
              diff << patch.split("\n")
            end
          end

          diff.flatten!
          diff.deep_dup
        rescue Octokit::Error
          nil
        end

        def annotate(path, identifier = nil)
          identifier = default_branch if identifier.blank?
          content = cat(path, identifier)
          return nil if content.nil?

          blame = Annotate.new
          revision = lastrev(path, identifier)
          content.split("\n").each do |line|
            blame.add_line(line, revision)
          end
          blame
        rescue Octokit::Error
          nil
        end

        def cat(path, identifier = nil)
          identifier = default_branch if identifier.nil?
          return nil if identifier.nil?

          file = @client.contents(@repo, :path => path, :ref => identifier)
          encoded = file.respond_to?(:content) ? file.content.to_s : ''
          encoding = file.respond_to?(:encoding) ? file.encoding.to_s : ''
          return Base64.decode64(encoded) if encoding.casecmp('base64').zero?
          encoded
        rescue Octokit::Error
          nil
        end

        class Revision < Redmine::Scm::Adapters::Revision
          def format_identifier
            identifier[0, 8]
          end
        end

        def valid_name?(name)
          true
        end

        private

        def default_branch_from_repository
          @default_branch ||= begin
            repo = @client.repo(@repo)
            repo.default_branch.to_s
          rescue Octokit::Error
            nil
          end
        end

        def extract_repo_path(url, root_url)
          repo_path = URI.parse(url).path.to_s.sub(%r{\A/}, '').sub(/\.git$/, '')
          root_path = ''
          unless root_url.to_s.blank?
            root_path = URI.parse(root_url).path.to_s.sub(%r{\A/}, '').sub(%r{/\z}, '')
          end
          if !root_path.blank? && repo_path.start_with?("#{root_path}/")
            repo_path[(root_path.length + 1)..-1]
          else
            repo_path
          end
        rescue URI::InvalidURIError
          ''
        end

        def normalize_api_endpoint(url, root_url)
          source = root_url.to_s.blank? ? url.to_s : root_url.to_s
          uri = URI.parse(source)
          return 'https://api.github.com/' if uri.host.to_s.casecmp('github.com').zero?

          base_path = uri.path.to_s.sub(%r{/\z}, '')
          if base_path.include?('/api/')
            "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if uri.port && ![80, 443].include?(uri.port)}#{base_path}/"
          else
            "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if uri.port && ![80, 443].include?(uri.port)}#{base_path}/api/v3/"
          end
        rescue URI::InvalidURIError
          'https://api.github.com/'
        end

        def commit_message(commit)
          if commit.respond_to?(:commit) && commit.commit && commit.commit.respond_to?(:message)
            commit.commit.message.to_s
          elsif commit.respond_to?(:message)
            commit.message.to_s
          else
            ''
          end
        end

        def commit_author_name(commit)
          if commit.respond_to?(:commit) && commit.commit && commit.commit.respond_to?(:author) && commit.commit.author
            commit.commit.author.name.to_s
          elsif commit.respond_to?(:author) && commit.author
            commit.author.login.to_s
          else
            ''
          end
        end

        def commit_time(commit)
          raw_time =
            if commit.respond_to?(:commit) && commit.commit && commit.commit.respond_to?(:author) && commit.commit.author
              commit.commit.author.date
            elsif commit.respond_to?(:committed_at)
              commit.committed_at
            else
              nil
            end
          raw_time.is_a?(Time) ? raw_time : Time.parse(raw_time.to_s)
        rescue
          Time.now
        end
      end
    end
  end
end
