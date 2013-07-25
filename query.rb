require 'JSON'

filename = ARGV[0] || 'properties.json'

contents = File.read(filename)
properties = JSON.parse(contents)

# Get every device and android.os.Build.MODELs associated with it
properties.each_pair do |key, value|
  model = value['android.os.Build.MODEL']
  next if model.nil?

  puts "#{key} = #{model.inspect}"
end

