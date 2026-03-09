module GitlabRepositoriesHelperPatch
  def repository_field_tags(form, repository)
    if repository && repository.scm_name.to_s.casecmp('Gitlab').zero?
      return gitlab_field_tags(form, repository)
    end
    super
  end

  def gitlab_field_tags(form, repository)
    content_tag('p', form.text_field(:url, :size => 60, :required => true,
                     :disabled => !repository.safe_attribute?('url')) +
    scm_path_info_tag(repository)) +
    content_tag('p', form.password_field(
                        :password, :size => 60, :name => 'ignore',
                        :label => 'API Token', :required => true,
                        :value => ((repository.new_record? || repository.password.blank?) ? '' : ('x' * 15)),
                        :onfocus => "this.value=''; this.name='repository[password]';",
                        :onchange => "this.name='repository[password]';")) +
    content_tag('p', form.text_field(:root_url, :size => 60) + gitlab_root_url_tag) +
    content_tag('p', form.check_box(
                        :report_last_commit,
                        :label => l(:label_git_report_last_commit)
                         ))
  end

  # Compatibility aliases for Redmine versions that resolve SCM helper names differently.
  def gitlab_fields(form, repository)
    gitlab_field_tags(form, repository)
  end

  def repository_gitlab_field_tags(form, repository)
    gitlab_field_tags(form, repository)
  end

  def gitlab_root_url_tag
    text = l("text_gitlab_root_url_note", :default => '')
    if text.present?
      content_tag('em', text, :class => 'info')
    else
      ''
    end
  end
end
