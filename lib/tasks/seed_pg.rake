require "open-uri"
require "json"

namespace :photos do
  desc "Scrape and seed high-resolution PG-rated photography from Lorem Picsum (Curated Safe-For-Work collection)"
  task :seed_pg, [:count] => :environment do |_, args|
    count = (args[:count] || 15).to_i
    puts "Fetching #{count} curated PG-rated photographs from Lorem Picsum..."

    url = "https://picsum.photos/v2/list?page=1&limit=#{count}"
    response = URI.open(url, "User-Agent" => "Mozilla/5.0").read
    items = JSON.parse(response)

    user = User.first

    items.each_with_index do |item, idx|
      id = item["id"]
      author = item["author"]
      download_url = "https://picsum.photos/id/#{id}/1024/1024"
      title = "#{author} - Scene #{idx + 1}"
      desc = "Curated high-res photography by #{author} via Picsum"

      puts "[#{idx + 1}/#{items.length}] Downloading #{title} (#{download_url})..."
      begin
        tempfile = URI.open(download_url, "User-Agent" => "Mozilla/5.0")
        photo = Photo.new(title: title, description: desc, user: user)
        photo.image.attach(io: tempfile, filename: "picsum_#{id}.jpg", content_type: "image/jpeg")

        if photo.save
          puts "  -> Successfully saved Photo ID: #{photo.id}"
        else
          puts "  -> Failed: #{photo.errors.full_messages.join(', ')}"
        end
      rescue => e
        puts "  -> Error downloading image #{id}: #{e.message}"
      end
    end

    puts "Done! Total photos in database: #{Photo.count}"
  end
end
