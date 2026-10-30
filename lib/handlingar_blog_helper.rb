# -*- encoding : utf-8 -*-
# Sync WordPress posts from BLOG_FEED for homepage teasers (booklet 3.1).
require 'net/http'
require 'uri'

module HandlingarBlogHelper
  FRONTPAGE_BLOG_LIMIT = 3

  def blog_posts_for_frontpage
    sync_handlingar_blog_posts_if_needed
    Blog::Post.order(id: :desc).limit(FRONTPAGE_BLOG_LIMIT)
  end

  def handlingar_blog_excerpt(post)
    excerpt = strip_tags(post.description.to_s)
    excerpt = excerpt.sub(/\s*The post .+ appeared first on .+\z/im, '')
    excerpt = excerpt.sub(/\s*Inlägget .+ dök först upp på .+\z/im, '')
    truncate(excerpt.squish, length: 180)
  end

  def handlingar_blog_image_url(post)
    data = post.respond_to?(:data) ? post.data : nil
    return if data.blank?

    candidates = []
    %w[media:content media:thumbnail enclosure].each do |key|
      Array(data[key]).each { |node| candidates << media_node_url(node) }
    end
    # The RSS feed omits the WordPress featured image. The sync stores it here.
    candidates << data['handlingar_cover']
    # XmlSimple stores WordPress <content:encoded> as data['encoded'].
    %w[encoded content:encoded description].each do |key|
      Array(data[key]).each { |html| candidates << first_img_src(html) }
    end

    candidates.compact.find { |url| url.match?(%r{\Ahttps?://}i) && !icon_image?(url) }
  end

  private

  def media_node_url(node)
    return node if node.is_a?(String) && node.match?(%r{\Ahttps?://}i)
    return unless node.is_a?(Hash)

    node['url'] || node['href']
  end

  def first_img_src(html)
    html.to_s[/<img[^>]+src=["']([^"']+)["']/i, 1]
  end

  def icon_image?(url)
    url.match?(/favicon|cropped-|-\d{2}x\d{2}\./i)
  end

  def sync_handlingar_blog_posts_if_needed
    return unless Blog.enabled?
    return if @handlingar_blog_synced

    @handlingar_blog_synced = true

    stale = Blog::Post.none? ||
            Blog::Post.maximum(:updated_at).nil? ||
            Blog::Post.maximum(:updated_at) < 1.hour.ago

    Blog.new.posts if stale
    store_missing_covers
  rescue StandardError => e
    Rails.logger.warn("Handlingar blog sync failed: #{e.message}")
  end

  # WordPress featured images are not in the RSS item. Read og:image once per post.
  def store_missing_covers
    Blog::Post.order(id: :desc).limit(FRONTPAGE_BLOG_LIMIT).each do |post|
      data = post.data.is_a?(Hash) ? post.data : {}
      next if data.key?('handlingar_cover')
      next if handlingar_blog_image_url(post)

      post.update(data: data.merge('handlingar_cover' => open_graph_image(post.url).to_s))
    end
  end

  def open_graph_image(page_url)
    html = fetch_html(page_url)
    return if html.blank?

    url = html[/<meta[^>]*property=["']og:image["'][^>]*content=["']([^"']+)["']/i, 1]
    url ||= html[/content=["']([^"']+)["'][^>]*property=["']og:image["']/i, 1]
    url if url.to_s.match?(%r{\Ahttps?://}i)
  end

  def fetch_html(page_url, limit = 3)
    return if limit.zero?

    uri = URI.parse(page_url.to_s)
    return unless uri.is_a?(URI::HTTP)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 8) do |http|
      http.request(Net::HTTP::Get.new(uri, 'User-Agent' => 'Handlingar'))
    end
    case response
    when Net::HTTPRedirection
      fetch_html(URI.join(uri, response['location']).to_s, limit - 1)
    when Net::HTTPSuccess
      response.body.to_s.byteslice(0, 200_000)
    end
  rescue StandardError
    nil
  end
end
