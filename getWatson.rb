require 'mechanize'
require 'logger'
require 'pry'
require 'zip/zip'

class GetWatson
  attr_accessor :agent, :first_page, :chapter_markers

  def initialize()
    @agent = Mechanize.new
    @agent.log = Logger.new "mech.log"
    @agent.user_agent_alias = 'Mac Safari'
  end

  def start_download
    # Start with first page of first Chapter
    base_url = "http://www.watsonstrip.com/archives/"
    page = @agent.get("#{base_url}")
    puts @agent.current_page().uri()
    current_chapter = 1
    results = page.search(".post img")
    results.reverse.each_with_index{ |image, index|
      index = index + 1
      if index % 20 == 0
        zip_previous_chapter(current_chapter)
        current_chapter = current_chapter + 1
        puts "Chapter switched to -> " + current_chapter.to_s
      end
      comic_url = image.attributes["src"].to_s
      image_name = comic_url.split('/')[-1]
      begin
        puts "Currently Downloading: #{current_chapter}"
        puts "Downloading comic address: #{comic_url}"
        @agent.get("#{comic_url}").save("#{chapter_directory(current_chapter)}/#{index}_#{image_name}")
      rescue Net::HTTPNotFound, Mechanize::ResponseCodeError => e
        puts "Error Downloading: #{comic_url}"
      rescue Mechanize::UnsupportedSchemeError => e
        begin
          File.open("#{chapter_directory(current_chapter)}/#{index}_#{image_name}.jpeg", 'wb') do |f|
            jpg = Base64.decode64(comic_url['data:image/jpeg;base64,'.length..-1])
            f.write(jpg)
          end
        rescue
          puts "saving failed on base 64 jpg..."
        end
      end

      if index == results.count
        zip_previous_chapter(current_chapter)
      end
    }
  end

  def chapter_directory(chapter_id)
    "watson_comics/watson_chapter_#{chapter_id}"
  end

  def zip_file_path(chapter_id)
    directory_name = "saved_comics"
    unless File.directory?(directory_name)
      FileUtils.mkdir_p(directory_name)
    end
    "#{directory_name}/watson_chapter_#{chapter_id}.cbz"
  end

  def zip_previous_chapter(chapter_id)
    directory = chapter_directory(chapter_id)
    zipfile_name = zip_file_path(chapter_id)
    if File.exist?(zipfile_name)
      File.delete(zipfile_name)
    end
    Zip::ZipFile.open(zipfile_name, 'w') do |zipfile|
      Dir["#{directory}/**/**"].reject{|f|f==zipfile_name}.each do |file|
        zipfile.add(file.sub(directory+'/',''),file)
      end
    end
  end

  class << self
    def new_download()
      scary_downloader = self.new()
      scary_downloader.start_download
    end
  end

end

GetWatson.new_download()

exit
