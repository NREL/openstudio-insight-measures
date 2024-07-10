require 'fileutils'
require 'openstudio'

# note: this version of script modified from what is in BESTEST-GSR repo

# expects single argument with path to directory that contains datapoints
#path_datapoints = 'run/MyProject'
#path_datapoints = ARGV[0]
path_datapoints = "build/"

# create a hash to contain all results data vs. simple CSV rows
results_hash = {}
failed_array = []
not_finished = []

# loop through resource files
results_directories = Dir.glob("#{path_datapoints}*")
results_directories.each do |results_directory|

  # since report is generated here need to skip when found
  next if results_directory == "build/workflow_testing_results.csv"

  row_data = {}

  # a little cleaner than seeing if osw is initialized
  if !File.exists?("#{File.dirname(__FILE__)}/#{results_directory}/out.osw")
    #puts "#{results_directory} osw cannot be found"
    not_finished << results_directory
    next
  end

  # load OSW to get information from argument values
  osw_path = OpenStudio::Path.new("#{File.dirname(__FILE__)}/#{results_directory}/out.osw")
  osw = OpenStudio::WorkflowJSON.load(osw_path)
  if !osw.is_initialized
    #puts "#{results_directory} has not been run"
    not_finished << osw_path
    next
  else
    osw = osw.get
  end
  runner = OpenStudio::Measure::OSRunner.new(osw)

  # store high level information about datapoint
  dir_string = results_directory.gsub(path_datapoints, "")
  row_data["_id"] = dir_string[0..dir_string.size - 4]
  #row_data["_name"] = runner.workflow.name

  # can't get OSW name attribute from runner, so parsing the JSON manually
  require 'json'
  temp_osw = nil
  temp_path = "#{File.dirname(__FILE__)}/#{results_directory}/data_point.osw"
  File.open(temp_path, 'r') do |f|
    temp_osw = JSON::parse(f.read, :symbolize_names => true)
  end
  row_data["_name"] = temp_osw[:name]

  row_data["status"] = runner.workflow.completedStatus.get
  if row_data["status"] != "Success"
    failed_array << row_data["_name"]
  end

  puts "#{row_data["_name"]}: #{row_data["status"]}"

  runner.workflow.workflowSteps.each do |step|
    if step.to_MeasureStep.is_initialized

      measure_step = step.to_MeasureStep.get
      measure_dir_name = measure_step.measureDirName

      # for manual PAT projects I want to pass in the measure dir name as the header instead of the measure option name
      measure_step_name = measure_dir_name.downcase.gsub(" ", "_").to_sym
      # measure_step_name = measure_step.name.get.downcase.gsub(" ","_").to_sym

      next if !measure_step.result.is_initialized
      next if !measure_step.result.get.stepResult.is_initialized
      measure_step_result = measure_step.result.get.stepResult.get.valueName

      # populate registerValue objects
      result = measure_step.result.get
      next if result.stepValues.size == 0
      #row_data[measure_step_name] = measure_step_result
      result.stepValues.each do |value|
        # populate feature_hash (there is issue filed with value.units)
        row_data["#{measure_step_name}.#{value.name}"] = value.valueAsVariant.to_s
      end

      # populate results_hash
      results_hash[results_directory] = row_data

    else
      #puts "This step is not a measure"
    end

  end

end

# populate csv header
puts "#{results_hash.size} datapoints have run. #{failed_array.size} of them have failed. #{not_finished.size} datapoints have not finished yet."
headers = []
results_hash.each do |k, v|
  v.each do |k2, v2|
    if !headers.include? k2
      headers << k2
    end
  end
end
headers = headers.sort

# populate csv
require "csv"
csv_rows = []
results_hash.each do |k, v|
  arr_row = []
  headers.each { |header| arr_row.push(v.key?(header) ? v[header] : nil) }
  csv_row = CSV::Row.new(headers, arr_row)
  csv_rows.push(csv_row)
end

# save csv
csv_table = CSV::Table.new(csv_rows)
path_report = "build/workflow_testing_results.csv"
puts "saving csv file to #{path_report}"
File.open(path_report, 'w') { |file| file << csv_table.to_s }