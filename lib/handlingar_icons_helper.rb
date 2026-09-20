# -*- encoding : utf-8 -*-
# Inline local SVG icons (Iconoir outline, Simple Icons for social).
# Colour comes from CSS currentColor — do not use a webfont.
module HandlingarIconsHelper
  ICON_DIR = File.expand_path('../../app/assets/images/icons', __FILE__).freeze

  ALLOWED = %w[
    antenna-signal
    mail-open
    lock
    view-grid
    bell
    page
    edit-pencil
    mail
    globe
    user-plus
    book
    facebook
    x
  ].freeze

  def ds_icon(name, html_class: 'ds-icon')
    name = name.to_s
    unless ALLOWED.include?(name)
      raise ArgumentError, "Unknown icon #{name.inspect}"
    end

    svg = File.read(File.join(ICON_DIR, "#{name}.svg"))
    classes = ERB::Util.html_escape(html_class.to_s)

    svg = svg.sub(/\A\s*<\?xml[^>]*\?>\s*/i, '')
    svg = svg.gsub(%r{<title\b[^>]*>.*?</title>}mi, '')

    svg.sub!(/<svg\b([^>]*)>/i) do
      attrs = Regexp.last_match(1)
      attrs = attrs.gsub(/\s+(width|height|role)="[^"]*"/i, '')
      if attrs =~ /\bclass="/i
        attrs = attrs.sub(/\bclass="/i, "class=\"#{classes} ")
      else
        attrs = %( class="#{classes}"#{attrs})
      end
      attrs += ' fill="currentColor"' unless attrs =~ /\bfill="/i
      %(<svg aria-hidden="true" focusable="false"#{attrs}>)
    end

    svg.html_safe
  end
end
