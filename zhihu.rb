require 'rest-client'
require 'json'
require_relative 'error'

class ZhihuActivity
  attr_reader :action, :actor, :created_at, :id
  attr_reader :title, :link, :content, :content_type

  def initialize(activity)
    @action = activity['action_text']
    @actor = activity.dig('actor', 'name')
    @created_at = Time.at(activity['created_time'].to_i)
    @id = acvitity['id']
    get_variant_fields activity
  end

  private

  def get_variant_fields(activity)
    @action_type = activity['verb']
    case @action_type
    when 'ANSWER_VOTE_UP'   @content_type = :answer
    when 'ANSWER_CREATE'    @content_type = :answer
    when 'QUESTION_FOLLOW'  @content_type = :question
    when 'MEMBER_CREATE_ARTICLE' @content_type = :article
    when 'MEMBER_VOTEUP_ARTICLE' @content_type = :article
    when 'MEMBER_CREATE_PIN'     @content_type = :pin
    else raise ContentParseError, "Unknown action type: #{@action_type}"
    end

    api_url = activity.dig('target', 'url')

    if @content_type == :answer
      @title = activity.dig('target', 'question', 'title')
      @link = api_url.gsub('api', 'www').gsub('answers', 'answer')
      @content = activity.dig('target', 'content')
    end

    if @content_type == :pin
      @title = activity.dig('target', 'excerpt_title')
      @link = api_url.gsub('api', 'www').gsub('pins', 'pin')
      # TODO: More content types in PIN?
      @content = activity.dig('target', 'content').map { |l| "<p>#{l}</p>" }.join
    end

    if @content_type == :article
      @title = title = activity.dig('target', 'title')
      @link = api_url.gsub('api', 'zhuanlan').gsub('articles', 'p')
      @content = activity.dig('target', 'content')
    end

    if @content_type == :question
      @title = activity.dig('target', 'title')
      @link = api_url.gsub('api', 'www').gsub('questions', 'question')
    end
  end
end

class ZhihuFetcher
  attr_reader :user_id, :items

  def initialize(id)
    @user_id = id
    @feed_num = 20
    @fetch_num = 7
  end

  def get_items
    # TODO: Filter by num of items
    @items = []
    fetch_zhihu_content(activities_url(@user_id), @user_id)
    parse_and_fetch_rest((@feed_num / @fetch_num.to_f).ceil)
  end

  private

  def parse_and_fetch_rest(total)
    @response['data'].each do |item|
      @items << ZhihuActivity.new(item)
    end
    return if total <= 1 || @response.dig('paging', 'is_end')
    next_url = @response['paging']['next']
    fetch_zhihu_content(next_url, @user_id)
  end

  def activities_url(uid)
    "https://www.zhihu.com/api/v3/feed/members/#{uid}/activities?limit=#{fetch_num}&desktop=true"
  end

  def fetch_zhihu_content(url, uid)
    resp = RestClient.get(url, {
      'Referer': "https://www.zhihu.com/people/#{uid}",
      'x-api-version': '3.0.40',
      'x-requested-with': 'fetch',
      'Host': 'www.zhihu.com',
      'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:77.0) Gecko/20100101 Firefox/77.0',
    })

    if resp.code != 200
      raise ContentFetchError, resp
    end

    @response = JSON.parse(resp)
  end
end
