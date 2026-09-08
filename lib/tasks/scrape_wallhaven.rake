require "json"
require "tempfile"
require "uri"

namespace :photos do
  desc "Scrape high-res SFW (Safe For Work / No Adult Content) wallpapers from Wallhaven by query or toplist"
  task :scrape_wallhaven, [:query, :count] => :environment do |_, args|
    query = (args[:query] || "").to_s.strip
    count = (args[:count] || 15).to_i

    q_param = query.empty? ? "" : "&q=#{URI.encode_www_form_component(query)}"
    # purity=100 forces strict SFW only (0% adult/NSFW content)
    # categories=111 enables General, Anime, and People
    url = "https://wallhaven.cc/api/v1/search?purity=100&categories=111&sorting=toplist#{q_param}&page=1"

    puts "Searching Wallhaven for SFW wallpapers (query: '#{query.empty? ? 'Toplist' : query}', count: #{count})..."
    json_str = `curl -s -L -A "My3DCube/1.0" "#{url}"`
    data = JSON.parse(json_str) rescue {}
    items = data["data"] || []

    if items.empty?
      puts "No wallpapers found for query '#{query}'."
      next
    end

    user = User.first
    selected_items = items.first(count)

    selected_items.each_with_index do |item, idx|
      id = item["id"]
      image_url = item["path"]
      cat = item["category"].to_s.capitalize
      res = item["resolution"]
      title = query.empty? ? "#{cat} Art (#{res})" : "#{query.capitalize} • #{cat} (#{id})"
      desc = "Curated SFW #{cat} artwork from Wallhaven (#{res})"

      puts "[#{idx + 1}/#{selected_items.length}] Downloading #{title} from #{image_url}..."
      ext = item["file_type"] == "image/png" ? ".png" : ".jpg"
      temp_file = Tempfile.new(["wallhaven_#{id}", ext])
      temp_file.binmode

      begin
        success = system("curl", "-s", "-L", "-A", "Mozilla/5.0", "-o", temp_file.path, image_url)
        if success && File.size?(temp_file.path)
          photo = Photo.new(title: title, description: desc, user: user)
          photo.image.attach(
            io: File.open(temp_file.path),
            filename: "wallhaven_#{id}#{ext}",
            content_type: item["file_type"] || "image/jpeg"
          )

          if photo.save
            puts "  -> Saved Photo ID #{photo.id}: #{title}"
          else
            puts "  -> Failed to save: #{photo.errors.full_messages.join(', ')}"
          end
        else
          puts "  -> Download failed for #{id}."
        end
      rescue => e
        puts "  -> Error: #{e.message}"
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    puts "Finished! Total photos in gallery: #{Photo.count}"
  end
end
