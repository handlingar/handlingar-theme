# -*- encoding : utf-8 -*-
# Sync WordPress posts from BLOG_FEED for homepage teasers (booklet 3.1).
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

  private

  def sync_handlingar_blog_posts_if_needed
    return unless Blog.enabled?
    return if @handlingar_blog_synced

    @handlingar_blog_synced = true

    stale = Blog::Post.none? ||
            Blog::Post.maximum(:updated_at).nil? ||
            Blog::Post.maximum(:updated_at) < 1.hour.ago

    Blog.new.posts if stale
  rescue StandardError => e
    Rails.logger.warn("Handlingar blog sync failed: #{e.message}")
  end
end
