require 'fileutils'
require 'csv'
require 'json'

# load CSV files for ee measure sampling as hash

# inputs for exp 1
csv_file = 'sampling_1.csv'
osw_file = 'workflows/os_insight.osw'
run_prefix = 'insight'

csv_hash = {}
CSV.foreach(csv_file, :headers => true, :header_converters => :symbol, :converters => :all) do |row|
  short_name = row.fields[0] # => .split(" ").first
  csv_hash[short_name] = Hash[row.headers[1..-1].zip(row.fields[1..-1])]
end
puts "CSV has #{csv_hash.size} entries."
puts "Hash keys are #{csv_hash.keys}"

# make build dir
# todo - with current code need to run script from directory it is in
target_directory = "build"
Dir.mkdir(target_directory) unless File.exists?(target_directory)

# array for diagnostic purposes where no ee measure is applied to a datapoint
no_ee_applied = []
counter = 0

# loop through each ee measure, and then the intensity for each ee measure
csv_hash.each do |k, v|

  ee_var = v[:ee_var]
  ee_status = v[:ee_status]
  if ee_status != "run"
    puts " "
    puts "No OSW's needed for #{k}"
  else
    puts " "
    puts "creating osw files for #{k}"
    puts v

    # loop through each sample making OSW
    v.each do |k2, v2|

      next if k2 == :ee_var
      next if k2 == :ee_status
      next if v2.nil?

      # save new osw
      if k2.to_s.length < 2 then
        k2 = "0#{k2}"
      else
        k2 = k2.to_s
      end # quick pad fix for sorting of directories, add better code for this later
      directory_name = "#{target_directory}/#{run_prefix}_#{k}_#{k2}"
      new_workflow_path = "#{directory_name}/data_point.osw"
      new_workflow_path = File.absolute_path(new_workflow_path)
      Dir.mkdir(directory_name) unless File.exists?(directory_name)
      FileUtils.cp(osw_file, new_workflow_path)
      counter += 1

      # load the new workflows
      new_osw = nil
      File.open(new_workflow_path, 'r') do |f|
        new_osw = JSON::parse(f.read, :symbolize_names => true)
      end

      # update measure paths for OSW
      new_path_array = []
      new_osw[:measure_paths].each do |path|
        new_path_array << "../#{path}"
      end
      new_osw[:measure_paths] = new_path_array

      # update file paths for OSW
      new_path_array = []
      new_osw[:file_paths].each do |path|
        new_path_array << "../#{path}"
      end
      new_osw[:file_paths] = new_path_array

      ee_enabled = false
      # loop through steps
      new_osw[:steps].each do |step|

        # set this measure to false for updated osw
        if step[:name] == k
          puts "changing #{ee_var} arg for #{k} to #{v2}"
          step[:arguments][:__SKIP__] = false
          step[:arguments][ee_var.to_sym] = v2
          new_osw[:name] = "#{k} #{v2}"
          ee_enabled = true
        elsif csv_hash.keys.include?(step[:name])
          next if step[:name].include?("WWR") # for some gbXMl files without windows I don't want to skip this measure
          step[:arguments][:__SKIP__] = true
        elsif step[:name] == "OpenStudio Results"
          # if measure name is row in csv then set skip to true
          step[:arguments][:__SKIP__] = false
        end

      end

      # log measures that don't have ee measure
      if ee_enabled == false
        no_ee_applied << directory_name
      end

      # add name if not already there (this will be used for baseline)
      if new_osw[:name].nil?
        new_osw[:name] = k
      end

      # save the configured osws
      File.open(new_workflow_path, 'w') do |f|
        f << JSON.pretty_generate(new_osw)
      end

    end

  end

end

# report warnings
if no_ee_applied.size > 0
  puts "** The following datapoints don't have a ee measures applied  **"
  no_ee_applied.each do |datapoint|
    puts datapoint
  end
end

# report number of datapoints
puts "generated #{counter} workflows."