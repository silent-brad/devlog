=begin
Minblog: Minimal static markdown blog generator written with Ruby and Nix
=end

require 'kramdown'
require 'listen'
require 'yaml'
require 'erb'
require 'webrick'

# Define source and destination directories
source_dir = 'blog'
dest_dir = 'www'

# Function to parse metadata and content from a Markdown file
def parse_md_file(md_file)
  content = File.read(md_file)
  if content.start_with?("---\n")
    parts = content.split("---\n", 3)
    if parts.size >= 3
      metadata_str = parts[1]
      content = parts[2]
      # Allow Date and Time classes in YAML parsing
      metadata = YAML.safe_load(metadata_str, permitted_classes: [Date, Time])
    else
      metadata = {}
      content = parts[0]
    end
  else
    metadata = {}
  end
  [metadata, content]
end

# Function to convert a Markdown file to HTML using a template
def convert_single_md_to_html(md_file, dest_dir)
  metadata, md_content = parse_md_file(md_file)
  content_html = Kramdown::Document.new(md_content).to_html
  title = metadata['title'] || 'Untitled'
  date = metadata['date'] || 'No date'
  template = ERB.new(File.read('template.html'))
  rendered_html = template.result(binding)
  html_file = File.join(dest_dir, File.basename(md_file, '.md') + '.html')
  File.write(html_file, rendered_html)
end

# Function to delete the corresponding HTML file
def delete_corresponding_html(md_file, dest_dir)
  html_file = File.join(dest_dir, File.basename(md_file, '.md') + '.html')
  File.delete(html_file) if File.exist?(html_file)
end

def generate_posts_page(source_dir, dest_dir)
  posts_data = []

  Dir.glob(File.join(source_dir, '*.md')).each do |md_file|
    metadata, _ = parse_md_file(md_file)
    posts_data.push({
      title: metadata['title'] || 'Untitled',
      date: metadata['date'] || 'No date',
      link: File.basename(md_file, '.md')
    })
  end

  # Sort by date
  posts_data.sort_by { |post_data| [post_data['date']] }

  template = ERB.new(File.read('posts.html'))
  rendered_html = template.result(binding)
  
  html_file = File.join(dest_dir, 'posts.html')
  File.write(html_file, rendered_html)
end

# Perform initial conversion of all Markdown files
Dir.glob(File.join(source_dir, '*.md')).each do |md_file|
  convert_single_md_to_html(md_file, dest_dir)
end

# Perform initial generation of posts page
# NOTE Check if blog directory is empty ->
generate_posts_page(source_dir, dest_dir)

# Set up listener to monitor the 'blog' directory for changes to .md files
listener = Listen.to(source_dir, only: /\.md$/) do |modified, added, removed|
  (modified + added).each do |file|
    convert_single_md_to_html(file, dest_dir)
  end
  removed.each do |file|
    delete_corresponding_html(file, dest_dir)
  end

  # Update/generate posts page
  if added.size > 0 || removed.size > 0
    generate_posts_page(source_dir, dest_dir)
  end
end

# Start the listener
listener.start

# Custom File Handler to enforce serving rules
class CustomFileHandler < WEBrick::HTTPServlet::FileHandler
  def do_GET(req, res)
    begin
      super # Serve the requested path directly
    rescue WEBrick::HTTPStatus::NotFound
      if req.path != '/' && File.extname(req.path).empty?
        html_path = req.path + '.html' # Append ".html" to extensionless paths
        full_path = File.join(@root, html_path[1..-1]) # Use @root, remove leading "/"
        if File.exist?(full_path)
          res.body = File.read full_path
          res['Content-Type'] = 'text/html'
        else
          # Re-raise 404 if HTML file doesn’t exist
          res.body = File.read File.join(@root, "404.html")
          res['Content-Type'] = 'text/html'
        end
      else
        # Re-raise 404 if HTML file doesn’t exist
        res.body = File.read File.join(@root, "404.html")
        res['Content-Type'] = 'text/html'
      end
    end
  end
end

# Start WEBrick server with custom file handler
server = WEBrick::HTTPServer.new(Port: 8080)
server.mount('/', CustomFileHandler, dest_dir)

# Run the server in a separate thread
Thread.new do
  server.start
end

# Keep the script running
loop { sleep 1 }
