class LiquidAssignsService
  AVAILABLE_PROJECT_ASSIGNS = %w{ evidences issues nodes notes tags }.freeze

  attr_accessor :project, :text

  def initialize(project:, text: nil)
    @project = project
    @text = text
  end

  def assigns
    result = project_assigns
    result.merge!(assigns_pro) if defined?(Dradis::Pro)
    result
  end

  private

  def assigns_pro
  end

  # This method uses Liquid::VariableLookup to find all liquid variables from
  # a given text. We use the list to know which project assign we need.
  def assigns_from_content
    return AVAILABLE_PROJECT_ASSIGNS if text.nil?

    variable_lookup = Liquid::VariableLookup.parse(text)
    return (variable_lookup.lookups & AVAILABLE_PROJECT_ASSIGNS)
  end

  def cached_drops(records)
    return [] if records.empty?

    type = records.first.class.to_s.underscore
    cache_key = "liquid-project-#{project.id}-#{type.pluralize}:#{records.maximum(:updated_at).to_i}-#{records.count}"
    drop_class = "#{type.camelize}Drop".constantize

    Rails.cache.fetch(cache_key) do
      records.map { |record| drop_class.new(record) }
    end
  end

  def project_assigns
    project_assigns = { 'project' => ProjectDrop.new(project) }

    assigns_from_content.each do |var|
      records =
        case var
        when 'evidences'
          project.evidence
        when 'nodes'
          project.nodes.user_nodes
        else
          project.send(var.to_sym)
        end

      project_assigns.merge!(var => cached_drops(records))
    end

    project_assigns
  end
end
