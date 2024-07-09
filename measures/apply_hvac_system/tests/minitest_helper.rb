require 'minitest/autorun'

require_relative '../apply_hvac_system'
require_relative 'config'

def run_command(command)
  stdout_str, stderr_str, status = Open3.capture3({}, command)
  if status.success?
    puts "Command completed successfully"
    puts "stdout: #{stdout_str}"
    puts "stderr: #{stderr_str}"
    return true
  else
    puts "Error running command: '#{command}'"
    puts "stdout: #{stdout_str}"
    puts "stderr: #{stderr_str}"
    return false
  end
end