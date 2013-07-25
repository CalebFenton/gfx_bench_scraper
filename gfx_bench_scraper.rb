=begin
/Users/cfenton/.rvm/gems/ruby-1.9.3-p374/gems/net-http-persistent-2.8/lib/net/http/persistent.rb:959:in `rescue in request': too many connection resets (due to Connection reset by peer - Errno::ECONNRESET) after 0 requests on 70301205247400, last used 1374783730.440896 seconds ago (Net::HTTP::Persistent::Error)
	from /Users/cfenton/.rvm/gems/ruby-1.9.3-p374/gems/net-http-persistent-2.8/lib/net/http/persistent.rb:968:in `request'
	from /Users/cfenton/.rvm/gems/ruby-1.9.3-p374/gems/mechanize-2.7.1/lib/mechanize/http/agent.rb:257:in `fetch'
	from /Users/cfenton/.rvm/gems/ruby-1.9.3-p374/gems/mechanize-2.7.1/lib/mechanize.rb:431:in `get'
	from gfx_bench_scraper.rb:58:in `get_device_properties'
	from gfx_bench_scraper.rb:20:in `block in get_properties!'
	from gfx_bench_scraper.rb:17:in `each'
	from gfx_bench_scraper.rb:17:in `get_properties!'
	from gfx_bench_scraper.rb:95:in `<main>'
=end

# TODO: tests
require 'rubygems'
require 'mechanize'
require 'json'
require 'pp'

class GFXBenchScraper
  ROOT_URL = 'http://gfxbench.com/'

  @agent = Mechanize.new {|a| a.max_history = 0}

  def self::get_properties!(properties, device_list = nil)
    device_list ||= GFXBenchScraper.get_device_list
    #puts "Device list to scrape: #{device_list}"

    count = 0
    device_list.each do |e|
      count += 1
      puts "Getting device properties: #{count}/#{device_list.size} - #{e}"
      device_properties = GFXBenchScraper.get_device_properties(e)

      properties.merge!(e => device_properties)
    end
  end

  def self::get_device_list
    device_list = []

    page = nil
    begin
      page = @agent.get("#{ROOT_URL}compare.jsp")
    rescue StandardError => e
      puts "Error requesting device list: #{e}"

      return device_list
    end

    form = page.form_with(:id => 'compare-form')
    select = form.field_with(:name => 'D1', :class => 'chzn-select')

    device_list += select.options.collect { |e| e.text }
    device_list.delete_if {|e| e.empty?}

    device_list
  end

  def self::get_device_properties(device)
    props = {}

    page = nil
    begin
      page = @agent.get("#{ROOT_URL}device.jsp?D=#{device}&testgroup=system")
    rescue StandardError => e
      puts "Error getting device properties for #{device}: #{e}"

      return props
    end

    page.search("//table[@class='platform-details']/tr").collect do |row|
      # First row, this is nil
      next if row.at('td[2]').nil?

      key = row.at('td[1]').text.to_sym
      value = row.at('td[2]').inner_html.split('<br>')

      # It's prettier this way.
      value = value[0] if value.size == 1
      props.merge!({key => value})
    end

    props
  end
end

out_file = ARGV[0] || 'properties.json'

properties = {}

begin
  if File.exist?(out_file)
    contents = File.read(out_file)

    # File already exist, load any devices we don't already have
    properties = JSON.parse(contents)

    device_list = GFXBenchScraper::get_device_list
    # Assume if we have non-blank info for this device
    # we don't need to update.
    device_list.delete_if do |e|
      properties.has_key?(e) && properties[e].size > 0
    end

    puts "Already have properties for #{properties.size} devices, skipping those."
    GFXBenchScraper.get_properties!(properties, device_list)
  else
    # Full scrape
    GFXBenchScraper.get_properties!(properties)
  end

rescue SystemExit, Interrupt
  puts "\nCtrl+C detected! Stopping and saving our progress."
rescue Exception => e
  puts "Uncaught #{e} exception while handling connection: #{e.message}"
  puts "Stack trace: #{backtrace.map {|l| "  #{l}\n"}.join}"
end

File.open(out_file, 'w') {|f| f.write(JSON.pretty_generate(properties))} unless properties.empty?