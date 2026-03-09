require 'redmine'
require_relative 'lib/gitlab_repositories_helper_patch'

Redmine::Plugin.register :redmine_gitlab_adapter do
  name 'Redmine Gitlab/Github Adapter plugin'
  author 'Future Corporation'
  description 'Gitlab and Github SCM adapters for Redmine'
  version '0.3.0'
  url 'https://www.future.co.jp'
  author_url 'https://www.future.co.jp'
  Redmine::Scm::Base.add "Gitlab"
  Redmine::Scm::Base.add "Github"
end

module RedmineGitlabAdapter
  module_function

  def apply_helper_patch
    begin
      require_dependency 'repositories_helper'
    rescue LoadError
      # Guarded below.
    end

    if defined?(RepositoriesHelper) && !RepositoriesHelper.ancestors.include?(GitlabRepositoriesHelperPatch)
      RepositoriesHelper.prepend(GitlabRepositoriesHelperPatch)
    end

    if defined?(ApplicationController)
      ApplicationController.helper(GitlabRepositoriesHelperPatch)
    end

    if defined?(RepositoriesController)
      RepositoriesController.helper(GitlabRepositoriesHelperPatch)
    end
  end
end

Rails.application.config.after_initialize do
  RedmineGitlabAdapter.apply_helper_patch
end

Rails.configuration.to_prepare do
  RedmineGitlabAdapter.apply_helper_patch
end
