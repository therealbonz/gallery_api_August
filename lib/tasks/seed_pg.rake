require "json"
require "tempfile"

namespace :photos do
  desc "Scrape and seed high-resolution PG-rated photography from Lorem Picsum (Curated Safe-For-Work collection)"
  task :seed_pg, [:count] => :environment do |_, args|
    count = (args[:count] || 15).to_i
    puts "Fetching #{count} curated PG-rated photographs from Lorem Picsum..."

    json_str = `curl -s -L "https://picsum.photos/v2/list?page=2&limit=#{count}"`
    items = JSON.parse(json_str) rescue []

    if items.empty?
      puts "No items returned from Picsum."
      next
    end

    user = User.first

    items.each_with_index do |item, idx|
      id = item["id"]
      author = item["author"]
      download_url = "https://picsum.photos/id/#{id}/1024/1024"
      title = "#{author} - Scene #{idx + 1}"
      desc = "Curated high-res photography by #{author} via Picsum"

      puts "[#{idx + 1}/#{items.length}] Downloading #{title} (#{download_url})..."
      temp_file = Tempfile.new(["picsum_#{id}", ".jpg"])
      temp_file.binmode

      begin
        success = system("curl", "-s", "-L", "-o", temp_file.path, download_url)
        if success && File.size?(temp_file.path)
          photo = Photo.new(title: title, description: desc, user: user)
          photo.image.attach(io: File.open(temp_file.path), filename: "picsum_#{id}.jpg", content_type: "image/jpeg")

          if photo.save
            puts "  -> Successfully saved Photo ID: #{photo.id}"
          else
            puts "  -> Failed: #{photo.errors.full_messages.join(', ')}"
          end
        else
          puts "  -> Failed to download image #{id}."
        end
      rescue => e
        puts "  -> Error downloading image #{id}: #{e.message}"
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    puts "Done! Total photos in database: #{Photo.count}"
  end
end
