require "fileutils"
require "tmpdir"

require "jekyll"

def assert_includes(actual, expected)
  return if actual.include?(expected)

  abort "Expected related posts to include #{expected.inspect}"
end

def refute_includes(actual, unexpected)
  return unless actual.include?(unexpected)

  abort "Expected related posts not to include #{unexpected.inspect}"
end

destination = Dir.mktmpdir("related-posts")

begin
  config = Jekyll.configuration(
    "source" => Dir.pwd,
    "destination" => destination,
    "future" => true,
    "quiet" => true
  )

  Jekyll::Site.new(config).process

  html = File.read(File.join(destination, "genai/2025/05/24/advanced-rag/index.html"))
  related = html.match(%r{<div class="related">.*?</div>}m).to_s

  assert_includes related, "PostgreSQL performance tuning with MCP and Claude"
  refute_includes related, "Google Cloud Professional Cloud Architect Certification Preparation Guide"

  puts "Related posts test passed"
ensure
  FileUtils.remove_entry(destination) if destination && Dir.exist?(destination)
end
