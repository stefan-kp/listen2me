module ApplicationHelper
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
