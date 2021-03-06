require 'httparty'
require 'yaml'
require 'json'
require 'progressbar'

PER_PAGE = 10 #number of posts Posterous' api returns per page

p "You must set up config.yml - look at the example config.yml.dist" and exit unless File.exists?('config.yml')
CONFIG = YAML.load_file('config.yml')

# Crack, HTTParty's default json parser, doesn't handle Posterous' 
# unclean json as well as the new core lib class
module HTTParty
  class JsonParser < HTTParty::Parser
    SupportedFormats.merge!({"application/json" => :json, "text/json" => :json})
    def json
      JSON.parse(body)
    end
  end
end

class Posterous
  include HTTParty
  base_uri 'posterous.com/api/2'
  basic_auth CONFIG['username'], CONFIG['password']
  parser HTTParty::JsonParser
end

p "No api_token found - visit http://posterous.com/api to view your api token" and exit unless CONFIG['api_token']
Posterous.default_params :api_token => CONFIG['api_token']
response = Posterous.get('/users/me')
p "Authentication failed" and exit unless response.code == 200

response = Posterous.get("/sites/#{CONFIG['site_id']}")
p "Invalid site id - please choose a site id from http://posterous.com/api/2/sites?api_token=#{CONFIG['token']}" and exit unless response.code == 200

parsed = response.parsed_response
hostname = parsed["full_hostname"]
site_name = parsed["name"]
subhead = parsed["subhead"]

Dir.mkdir(hostname) unless Dir.exists?(hostname)
Dir.chdir(hostname)
Dir.mkdir('_layouts') unless Dir.exists?('_layouts')
Dir.mkdir('_posts') unless Dir.exists?('_posts')
Dir.mkdir('images') unless Dir.exists?('images')
Dir.mkdir('css') unless Dir.exists?('css')
Dir.mkdir('js') unless Dir.exists?('js')
unless File.exists?("index.html")
  File.open("index.html", 'w') do |f|
    f.puts "---", "layout: default", "---"
    f.puts "<h1>#{site_name}</h1>"
    f.puts "<h3>#{subhead}</h3>"
  end
end

unless File.exists?("_config.yml")
  File.open("_config.yml", 'w') do |f|
    f.puts "---", "safe: true", "---"
  end
end

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
    image_files = []
    post["media"].each do |name, media|
      next if media.nil? || media.empty?
      if name == "images"
        media.each do |image_and_sizes|
          image_and_sizes.each do |size, image|
            filename = image["url"].split('/').last
            image_files << filename
            image_response = HTTParty.get(image["url"])
            next unless image_response.code == 200
            img = File.new("images/#{filename}", "w")
            img.puts image_response.parsed_response
            img.close
          end
        end
      end
      
      if name == "audio_files"
        media.each do |audio_files|
          # TODO: build this
        end
      end
      
      if name == "videos"
        media.each do |video|
          # TODO: build this
        end
      end
    end
    
    
    begin
      date = Date.parse(post['display_date'])
    rescue StandardError => e
      date = ''
    end
    
    slug = post["slug"]
    title = post["title"].gsub(/"/, '\"')
    body_full = post["body_full"]
    date_slug = date.strftime "%Y-%m-%d"
    image_files.each {|filename| escaped = filename.gsub(/\./, '\.'); body_full.gsub!(/http.*#{filename}/, "/images/#{filename}") }
    file = File.open("_posts/#{date_slug}-#{slug}.html", "w") do |f|
      f.puts "---", "layout: default", "title: \"#{title}\"", "permalink: \"#{slug}\"", "date: \"#{date_slug}\"", "---"
      f.puts body_full
    end
  end
  @pbar.inc
end

