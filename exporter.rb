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

post_count = response.parsed_response["posts_count"].to_i
total_pages = (post_count / PER_PAGE).ceil
#@pbar = ProgressBar.new "Downloading", post_count

(1..total_pages).to_a.each do |page|
  response = Posterous.get("/sites/#{CONFIG['site_id']}/posts", :query => {:page => page})
  p "Unable to process /sites/#{CONFIG['site_id']}/posts?page=#{page}" and next unless response.code == 200
  response.parsed_response.each do |post|
    
  end
end

