require "json"
require "tempfile"
require "uri"

namespace :photos do
  desc "Scrape 250 verified high-resolution SFW images across 5 diverse categories"
  task scrape_verified_250: :environment do
    puts "============================================================"
    puts "Starting scrape of 250 verified high-resolution SFW images"
    puts "Current photo count in database: #{Photo.count}"
    puts "============================================================"

    user = User.first
    total_needed = 250
    saved_count = 0

    # Helper to download and save a photo
    save_image_record = lambda do |title, desc, image_url, ext, content_type, unique_marker|
      if unique_marker.present? && Photo.where("title LIKE ? OR description LIKE ?", "%#{unique_marker}%", "%#{unique_marker}%").exists?
        puts "  -> Skipping #{unique_marker} (already exists in database)"
        return false
      end

      temp_file = Tempfile.new(["scraped_photo", ext])
      temp_file.binmode

      begin
        # Use curl -4 to force IPv4, set timeouts, and follow redirects
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
            puts "  -> [#{saved_count + 1}/#{total_needed}] Saved: #{title} (ID: #{photo.id})"
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

    # 1. Wallhaven SFW Scraper Helper
    scrape_wallhaven_category = lambda do |category_name, search_query, target_count|
      puts "\n>>> Category: #{category_name.upcase} (Target: #{target_count}) <<<"
      category_saved = 0
      page = 1

      while category_saved < target_count && page <= 6
        q_param = search_query.empty? ? "" : "&q=#{URI.encode_www_form_component(search_query)}"
        api_url = "https://wallhaven.cc/api/v1/search?purity=100&categories=111&sorting=toplist#{q_param}&page=#{page}"
        puts "Fetching Wallhaven page #{page} for #{category_name}..."

        json_str = `curl -4 -s -L --connect-timeout 10 --max-time 20 -A "Mozilla/5.0" "#{api_url}"`
        data = JSON.parse(json_str) rescue {}
        items = data["data"] || []

        if items.empty?
          puts "No items returned on page #{page} for #{category_name}."
          break
        end

        items.each do |item|
          break if category_saved >= target_count || saved_count >= total_needed

          id = item["id"]
          img_url = item["path"]
          cat = item["category"].to_s.capitalize
          res = item["resolution"] || "High-Res"
          title = "#{category_name} • #{cat} #{res} (#{id})"
          desc = "Verified curated SFW #{category_name} artwork from Wallhaven (#{res})"
          ext = item["file_type"] == "image/png" ? ".png" : ".jpg"
          content_type = item["file_type"] || "image/jpeg"

          puts "Downloading Wallhaven item #{id} (#{res})..."
          if save_image_record.call(title, desc, img_url, ext, content_type, id)
            category_saved += 1
            saved_count += 1
          end
        end

        page += 1
      end
      puts "Completed category #{category_name}: added #{category_saved} photos."
    end

    # 2. Lorem Picsum Photography Scraper Helper
    scrape_picsum_photography = lambda do |target_count|
      puts "\n>>> Category: NATURE, LANDSCAPES & ARCHITECTURE (Picsum Curated) (Target: #{target_count}) <<<"
      picsum_saved = 0
      page = 3

      while picsum_saved < target_count && page <= 10
        api_url = "https://picsum.photos/v2/list?page=#{page}&limit=50"
        puts "Fetching Picsum page #{page}..."

        json_str = `curl -4 -s -L --connect-timeout 10 --max-time 20 -A "Mozilla/5.0" "#{api_url}"`
        items = JSON.parse(json_str) rescue []

        if items.empty?
          puts "No items returned from Picsum on page #{page}."
          break
        end

        items.each do |item|
          break if picsum_saved >= target_count || saved_count >= total_needed

          id = item["id"]
          author = item["author"]
          img_url = "https://picsum.photos/id/#{id}/1920/1080"
          title = "#{author} - Landscape & Architecture (Picsum #{id})"
          desc = "Verified high-resolution photography by #{author} via Lorem Picsum"

          puts "Downloading Picsum photograph #{id} by #{author}..."
          if save_image_record.call(title, desc, img_url, ".jpg", "image/jpeg", "Picsum #{id}")
            picsum_saved += 1
            saved_count += 1
          end
        end

        page += 1
      end
      puts "Completed Picsum Photography: added #{picsum_saved} photos."
    end

    # Execute the 5 balanced categories (50 photos each = 250 total)
    # Category 1: Space & Deep Cosmos
    scrape_wallhaven_category.call("Space & Cosmos", "space nebula galaxy", 50)

    # Category 2: Cyberpunk & Synthwave
    scrape_wallhaven_category.call("Cyberpunk & Synthwave", "cyberpunk synthwave neon city", 50)

    # Category 3: Curated Nature & Architecture Photography (Picsum)
    scrape_picsum_photography.call(50)

    # Category 4: Digital Art & Sci-Fi
    scrape_wallhaven_category.call("Sci-Fi & Digital Art", "scifi futuristic concept art", 50)

    # Category 5: Gaming & Minimalist Tech
    scrape_wallhaven_category.call("Gaming & Tech", "gaming technology minimalist wallpaper", 50)

    # Final wrap-up if any category had short pages
    if saved_count < total_needed
      remaining = total_needed - saved_count
      puts "\n>>> Toplist Fill-in for remaining #{remaining} photos <<<"
      scrape_wallhaven_category.call("Curated Toplist", "", remaining)
    end

    puts "\n============================================================"
    puts "🎉 Scrape Complete! Total new photos added: #{saved_count}"
    puts "Final total photos in database: #{Photo.count}"
    puts "============================================================"
  end
end
