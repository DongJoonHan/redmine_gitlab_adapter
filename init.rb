require 'redmine'
require_relative 'lib/gitlab_repositories_helper_patch'

Redmine::Plugin.register :redmine_gitlab_adapter do
  name 'Redmine Gitlab Adapter plugin'
  author 'Future Corporation'
  description 'This is a Gitlab Adapter plugin for Redmine'
  version '0.2.1'
  url 'https://www.future.co.jp'
  author_url 'https://www.future.co.jp'
  Redmine::Scm::Base.add "Gitlab"
end

Rails.configuration.to_prepare do
  begin
    require_dependency 'repositories_helper'
  rescue LoadError
    # RepositoriesHelper may be loaded later; guard clauses below will skip patching safely.
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
