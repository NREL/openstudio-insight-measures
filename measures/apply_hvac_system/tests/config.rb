require 'openstudio'

module Config
  BASE_PATH = File.expand_path(__dir__)
  CLI_PATH = OpenStudio.getOpenStudioCLI
  OSM_FIXTURES = File.join(BASE_PATH + '/fixtures/osms/')
  OSM_OUTPUTS = File.join(BASE_PATH + '/outputs/')
end

puts Config::BASE_PATH