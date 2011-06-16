require 'httparty'
require 'yaml'
require 'progressbar'

PER_PAGE = 10 #number of posts Posterous' api returns per page

p "You must set up config.yml - look at the example config.yml.dist" and exit unless File.exists?('config.yml')
CONFIG = YAML.load_file('config.yml')

class Posterous
  include HTTParty
  base_uri 'posterous.com/api/2'
  basic_auth CONFIG['username'], CONFIG['password']
end

response = Posterous.get('/auth/token')
p "Authentication failed" and exit unless response.code == 200 && (CONFIG['token'] = response.parsed_response["api_token"])
Posterous.default_params :api_token => CONFIG['token']

response = Posterous.get("/sites/#{CONFIG['site_id']}")
p "Invalid site id - please choose a site id from http://posterous.com/api/2/sites?api_token=#{CONFIG['token']}" and exit unless response.code == 200

site_name = response.parsed_response['full_hostname']
Dir.mkdir(site_name) unless Dir.exists?(site_name)
Dir.chdir(site_name)
Dir.mkdir('_layouts') unless Dir.exists?('_layouts')
Dir.mkdir('_posts') unless Dir.exists?('_posts')
Dir.mkdir('images') unless Dir.exists?('images')
Dir.mkdir('css') unless Dir.exists?('css')
Dir.mkdir('js') unless Dir.exists?('js')

post_count = response.parsed_response["posts_count"].to_i
total_pages = (post_count / PER_PAGE).ceil
@pbar = ProgressBar.new "Downloading", total_pages

(1..total_pages).to_a.each do |page|
  response = Posterous.get("/sites/#{CONFIG['site_id']}/posts", :query => {:page => page})
  unless response.code == 200
    p "Unable to process /sites/#{CONFIG['site_id']}/posts?page=#{page}"
    @pbar.inc
    next
  end
  response.parsed_response.each do |post|
    begin
      date = Date.parse(post['display_date'])
    rescue StandardError => e
      date = ''
    end
    slug = post['slug']
    title = post["title"]
    file = File.new("#{date}-#{slug}.html", "w")
    file.puts post['body_full']
  end
  @pbar.inc
end

