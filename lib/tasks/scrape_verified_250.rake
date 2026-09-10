require "json"
require "tempfile"
require "uri"

namespace :photos do
  desc "Scrape verified high-resolution SFW images to reach target count of 362 photos (250 new additions)"
  task scrape_verified_250: :environment do
    target_total = 362
    current_total = Photo.count

    puts "============================================================"
    puts "Starting scrape to reach target total of #{target_total} photos (250 new)"
    puts "Current photo count in database: #{current_total}"
    puts "Needed: #{target_total - current_total}"
    puts "============================================================"

    if current_total >= target_total
      puts "Already reached target of #{target_total} photos! Exiting."
      next
    end

    user = User.first

    # Helper to download and save a photo
    save_image_record = lambda do |title, desc, image_url, ext, content_type, unique_marker|
      if unique_marker.present? && Photo.where("title LIKE ? OR description LIKE ?", "%#{unique_marker}%", "%#{unique_marker}%").exists?
        puts "  -> Skipping #{unique_marker} (already exists in database)"
        return false
      end

      temp_file = Tempfile.new(["scraped_photo", ext])
      temp_file.binmode

      begin
        cmd = [
          "curl", "-4", "-s", "-L",
          "--connect-timeout", "10",
          "--max-time", "35",
          "-A", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
          "-o", temp_file.path,
          image_url
        ]
        success = system(*cmd)
        if success && File.size?(temp_file.path) && File.size(temp_file.path) > 10_000
          photo = Photo.new(title: title, description: desc, user: user)
          photo.image.attach(
            io: File.open(temp_file.path),
            filename: "photo_#{Time.now.to_i}_#{rand(1000..9999)}#{ext}",
            content_type: content_type
          )

          if photo.save
            now_count = Photo.count
            puts "  -> [#{now_count}/#{target_total}] Saved: #{title} (ID: #{photo.id})"
            return true
          else
            puts "  -> Failed to save record: #{photo.errors.full_messages.join(', ')}"
          end
        else
          puts "  -> Download failed or file too small for: #{title} (#{image_url})"
        end
      rescue => e
        puts "  -> Error processing #{title}: #{e.message}"
      ensure
        temp_file.close
        temp_file.unlink
      end
      false
    end

    # 1. Lorem Picsum Photography (Ultra-reliable, high-res curated photography)
    if Photo.count < target_total
      puts "\n>>> Fetching Curated Photography from Lorem Picsum (Pages 5..8) <<<"
      (5..9).each do |page|
        break if Photo.count >= target_total

        api_url = "https://picsum.photos/v2/list?page=#{page}&limit=40"
        puts "Fetching Picsum page #{page}..."
        json_str = `curl -4 -s -L --connect-timeout 10 --max-time 20 -A "Mozilla/5.0" "#{api_url}"`
        items = JSON.parse(json_str) rescue []

        items.each do |item|
          break if Photo.count >= target_total

          id = item["id"]
          author = item["author"]
          img_url = "https://picsum.photos/id/#{id}/1920/1080"
          title = "#{author} - Curated Photo (Picsum #{id})"
          desc = "Verified high-resolution photography by #{author} via Lorem Picsum"

          puts "Downloading Picsum photograph #{id} by #{author}..."
          save_image_record.call(title, desc, img_url, ".jpg", "image/jpeg", "Picsum #{id}")
        end
      end
    end

    # 2. Wallhaven Single-Word Queries
    queries = ["cyberpunk", "space", "synthwave", "nature", "gaming", "neon", "architecture"]
    queries.each do |query|
      break if Photo.count >= target_total
      puts "\n>>> Fetching Wallhaven query: #{query.upcase} <<<"

      (1..4).each do |page|
        break if Photo.count >= target_total

        api_url = "https://wallhaven.cc/api/v1/search?purity=100&categories=111&sorting=toplist&q=#{query}&page=#{page}"
        puts "Fetching Wallhaven #{query} page #{page}..."
        json_str = `curl -4 -s -L --connect-timeout 10 --max-time 20 -A "Mozilla/5.0" "#{api_url}"`
        data = JSON.parse(json_str) rescue {}
        items = data["data"] || []

        break if items.empty?

        items.each do |item|
          break if Photo.count >= target_total

          id = item["id"]
          img_url = item["path"]
          cat = item["category"].to_s.capitalize
          res = item["resolution"] || "High-Res"
          title = "#{query.capitalize} • #{cat} #{res} (#{id})"
          desc = "Verified curated SFW #{query} artwork from Wallhaven (#{res})"
          ext = item["file_type"] == "image/png" ? ".png" : ".jpg"
          content_type = item["file_type"] || "image/jpeg"

          puts "Downloading Wallhaven #{query} item #{id} (#{res})..."
          save_image_record.call(title, desc, img_url, ext, content_type, id)
        end
        sleep 1 # respectful pause between Wallhaven API calls
      end
    end

    puts "\n============================================================"
    puts "🎉 Completed! Final total photos in database: #{Photo.count}"
    puts "Total photos added in this session: #{Photo.count - current_total}"
    puts "============================================================"
  end
end
