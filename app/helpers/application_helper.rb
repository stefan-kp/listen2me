module ApplicationHelper
  DEFAULT_CATEGORY_KEYS = {
    "Basic Needs" => "basic_needs",
    "Food" => "food",
    "Drinks" => "drinks",
    "Health" => "health",
    "Pain" => "pain",
    "Bathroom" => "bathroom",
    "Emotions" => "emotions",
    "Help" => "help",
    "Emergency" => "emergency",
    "Family" => "family",
    "Daily Care" => "daily_care",
    "Rest" => "rest",
    "Entertainment" => "entertainment",
    "Movement" => "movement",
    "Temperature" => "temperature"
  }.freeze

  def display_category_name(category)
    name = category.respond_to?(:name) ? category.name : category.to_s
    translation_key = DEFAULT_CATEGORY_KEYS[name]
    return name unless translation_key

    t("categories.default_names.#{translation_key}", default: name)
  end

  def markdown_to_html(text)
    return "" if text.blank?

    markdown = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new(
        safe_links_only: true,
        hard_wrap: true
      ),
      autolink: true,
      tables: true,
      fenced_code_blocks: true
    )

    sanitize markdown.render(text), tags: %w[p h1 h2 h3 h4 h5 h6 ul ol li strong em a blockquote code pre br]
  end
end
