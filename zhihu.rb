require 'rest-client'
require 'rss'
require 'json'
require 'htmlentities'

def fetch_zhihu_content(url, uid)
  resp = RestClient.get(url, {
    'Referer': "https://www.zhihu.com/people/#{uid}",
    'x-api-version': '3.0.40',
    'x-requested-with': 'fetch',
    'Host': 'www.zhihu.com',
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:77.0) Gecko/20100101 Firefox/77.0',
  })

  if resp.code != 200
    abort 'Failed to fetch'
  end

  JSON.parse(resp)
end

def parse_zhihu_item(activity, maker)
  id = activity['id']
  created = activity['created_time']
  author = activity.dig('actor', 'name') + activity['action_text']

  case activity['verb']
  when 'ANSWER_VOTE_UP'
    title = activity.dig('target', 'question', 'title')
    link = activity.dig('target', 'url').gsub('api', 'www').gsub('answers', 'answer')
    description = activity.dig('target', 'excerpt')
  when 'ANSWER_CREATE'
    title = activity.dig('target', 'question', 'title')
    title = activity.dig('target', 'question', 'title')
    link = activity.dig('target', 'url').gsub('api', 'www').gsub('answers', 'answer')
    description = activity.dig('target', 'content')
  when 'QUESTION_FOLLOW'
    title = activity.dig('target', 'title')
    link = activity.dig('target', 'url').gsub('api', 'www').gsub('questions', 'question')
    description = ''
  when 'MEMBER_CREATE_ARTICLE'
    title = activity.dig('target', 'title')
    link = activity.dig('target', 'url').gsub('api', 'zhuanlan').gsub('articles', 'p')
    description = activity.dig('target', 'content')
  when 'MEMBER_CREATE_PIN'
    title = activity.dig('target', 'excerpt_title')
    link = activity.dig('target', 'url').gsub('api', 'www').gsub('pins', 'pin')
    description = activity.dig('target', 'excerpt_new')
  when 'MEMBER_VOTEUP_ARTICLE'
    title = activity.dig('target', 'title')
    link = activity.dig('target', 'url').gsub('api', 'zhuanlan').gsub('articles', 'p')
    description = activity.dig('target', 'content')
  end

  if !link || !title || !description
    STDERR.puts "MISSING for type: #{activity['verb']}"
    return
  end

  maker.items.new_item do |item|
    item.link = link
    item.title = title
    item.updated = Time.at(created).to_s
    item.author = author
    item.id = id
    item.description = HTMLEntities.new.decode description
  end
end

def make_zhihu_atom(uid, feed_name)
  base_url = "https://www.zhihu.com/api/v3/feed/members/#{uid}/activities"
  url = "#{base_url}?limit=7&desktop=true"

  init_resp = fetch_zhihu_content(url, uid)
  name = init_resp['data'][0]['actor']['name']
  next_url = init_resp['paging']['next']

  RSS::Maker.make('atom') do |maker|
    maker.channel.author = uid
    maker.channel.updated = Time.now.to_s
    maker.channel.about = feed_name
    maker.channel.title = "#{name}的知乎动态"

    init_resp['data'].each do |activity|
      parse_zhihu_item(activity, maker)
    end
    3.times do
      resp = fetch_zhihu_content(next_url, uid)
      resp['data'].each do |activity|
        parse_zhihu_item(activity, maker)
      end
      next_url = resp['paging']['next']
      sleep 1
    end
  end
end

# Example
# puts make_zhihu_atom("SOMEONE's ID", "ARBITRARY URL")
