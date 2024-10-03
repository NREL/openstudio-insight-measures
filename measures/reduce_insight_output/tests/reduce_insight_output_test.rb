# insert your copyright here

require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require 'open3'

require_relative '../measure'

class ReduceInsightOutputTest < Minitest::Test

  def epw_path_default
    # make sure we have a weather data location
    epw = nil
    epw = OpenStudio::Path.new("#{__dir__}/USA_CO_Fort.Collins.AWOS.724769_TMY3.epw")
    assert(File.exist?(epw.to_s))
    return epw.to_s
  end

  def run_dir(test_name)
    # always generate test output in specially named 'output' directory so result files are not made part of the measure
    "#{__dir__}/output/#{test_name}"
  end

  def model_in_path(model_in_name)
    "#{__dir__}/#{model_in_name}"
  end

  def model_out_path(test_name)
    "#{run_dir(test_name)}/TestOutput.osm"
  end

  def workspace_path(test_name)
    "#{run_dir(test_name)}/run/in.idf"
  end

  def sql_path(test_name)
    "#{run_dir(test_name)}/run/eplusout.sql"
  end

  def get_run_env()
    new_env = {}
    new_env['BUNDLER_ORIG_MANPATH'] = nil
    new_env['BUNDLER_ORIG_PATH'] = nil
    new_env['BUNDLER_VERSION'] = nil
    new_env['BUNDLE_BIN_PATH'] = nil
    new_env['RUBYLIB'] = nil
    new_env['RUBYOPT'] = nil
    new_env['GEM_PATH'] = nil
    new_env['GEM_HOME'] = nil
    new_env['BUNDLE_GEMFILE'] = nil
    new_env['BUNDLE_PATH'] = nil
    new_env['BUNDLE_WITHOUT'] = nil

    return new_env
  end

  # create test files if they do not exist when the test first runs
  def run_measure_in_workflow(test_name, test_model_path, args_hash, epw_path = epw_path_default)

    # Check that the input model exists
    assert(File.exist?(test_model_path))

    # Check that the epw file exists
    assert(File.exist?(epw_path))

    FileUtils.mkdir_p(run_dir(test_name)) unless File.exist?(run_dir(test_name))
    assert(File.exist?(run_dir(test_name)))

    # Load the input model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    model = translator.loadModel(test_model_path)
    assert(model.is_initialized)
    model = model.get
    model.save(model_out_path(test_name), true)

    # Create an instance of the measure
    measure = ReduceInsightOutput.new

    # create and run workflow without measure or modifications
    osw_path = File.join(run_dir(test_name), 'in_nomeasure.osw')
    osw_path = File.absolute_path(osw_path)

    workflow = OpenStudio::WorkflowJSON.new
    workflow.setSeedFile(File.absolute_path(model_out_path(test_name)))
    workflow.setWeatherFile(File.absolute_path(epw_path))
    workflow.saveAs(osw_path)
    cli_path = OpenStudio.getOpenStudioCLI
    command = "\"#{cli_path}\" run -w \"#{osw_path}\""
    stdout_str, stderr_str, status = Open3.capture3(get_run_env(), command)

    assert(status.success?, "Error running command: '#{command}'\nstdout: #{stdout_str}\nstderr: #{stderr_str}")
    puts "Successfully ran #{File.basename(osw_path)}"

    # get size of all files in resulting dir
    before_size = Dir["#{run_dir(test_name)}/run/**/*"].select { |f| File.file?(f) }.sum { |f| File.size(f)}
    
    puts "Before measure, test file run dir is #{before_size} B"

    # add measure and make workflow modifications
    osw_path = File.join(run_dir(test_name), 'in_withmeasure.osw')
    osw_path = File.absolute_path(osw_path)
    assert(workflow.addMeasurePath(File.expand_path('../..', __dir__)))

    # add measure step to workflow
    measure_dirname = File.basename(File.dirname(File.expand_path(__dir__)))
    puts measure_dirname
    measure_name = 'Reduce Insight Output'
    step = OpenStudio::MeasureStep.new(measure_dirname)
    step.setName(measure_name)
    argument_hash = {'suppress_files'=> true}
    argument_hash.each { |k,v| step.setArgument(k,v) }
    assert(workflow.setMeasureSteps(OpenStudio::MeasureType.new('ModelMeasure'), [step]))

    # set FT options to reduce output
    # adds the following run options to the workflow - this is critical in reducing total filesize:
    # "run_options" : 
    # {
    #    "ft_options" : 
    #    {
    #       "no_html_output" : true,
    #       "no_lifecyclecosts" : true
    #    },
    #    "skip_energyplus_preprocess" : true,
    #    "skip_zip_results" : true
    # }
    fto = OpenStudio::ForwardTranslatorOptions.new
    fto.setExcludeHTMLOutputReport(true) # no HTML output will be added
    fto.setExcludeLCCObjects(true) # not LCC objects added to IDF
    # add to RunOptions
    ro = OpenStudio::RunOptions.new
    ro.setForwardTranslatorOptions(fto)
    ro.setSkipEnergyPlusPreprocess(true) # no custom Output:Tables or Output:Meters added by OpenStudio
    ro.setSkipZipResults(true) # don't create a separate zip of results files
    workflow.setRunOptions(ro)

    workflow.saveAs(osw_path)

    cli_path = OpenStudio.getOpenStudioCLI
    command = "\"#{cli_path}\" run -w \"#{osw_path}\""
    stdout_str, stderr_str, status = Open3.capture3(get_run_env(), command)

    assert(status.success?, "Error running command: '#{command}'\nstdout: #{stdout_str}\nstderr: #{stderr_str}")
    puts "Successfully ran #{File.basename(osw_path)}"

    # get size of all files in resulting dir
    after_size = Dir["#{run_dir(test_name)}/run/**/*"].select { |f| File.file?(f) }.sum { |f| File.size(f)}
    
    puts "After measure, test file run dir is #{after_size} B"
    puts "Total run dir file size reduced by #{(1.0-(after_size.to_f/before_size.to_f)).round(2)*100.0} %"

    # query sqlfile
    sqlFile = OpenStudio::SqlFile.new(OpenStudio::Path.new(sql_path(test_name)))

    total_building_area_m2 = 0.0
    var_val_query = "SELECT Value FROM TabularDataWithStrings WHERE ReportName = 'AnnualBuildingUtilityPerformanceSummary' AND ReportForString = 'Entire Facility' AND TableName = 'Building Area' AND RowName = 'Total Building Area' AND ColumnName = 'Area' AND Units = 'm2'"
    val = sqlFile.execAndReturnFirstDouble(var_val_query)
    assert(val.is_initialized, 'could not find total area in sqlFile')
    total_building_area_m2 = val.get
    total_building_area_ft2 = OpenStudio.convert(total_building_area_m2, 'm^2', 'ft^2').get

    tot_elec = sqlFile.electricityTotalEndUses
    assert(tot_elec.is_initialized, 'could not find total elec')
    tot_elec = tot_elec.get
    tot_elec_kbtu = OpenStudio.convert(tot_elec, 'GJ', 'kBtu').get

    tot_gas = sqlFile.naturalGasTotalEndUses
    assert(tot_gas.is_initialized, 'could not find total gas')
    tot_gas = tot_gas.get
    tot_gas_kbtu = OpenStudio.convert(tot_gas, 'GJ', 'kBtu').get

    puts "#{(tot_elec_kbtu / total_building_area_ft2).round(2)} Elec EUI"
    puts "#{(tot_gas_kbtu / total_building_area_ft2).round(2)} Gas EUI"
  end

  def test_run_workflow
    test_name = __method__.to_s
    test_model_path = model_in_path('smalloffice.osm')
    args_hash = {}
    args_hash['suppress_files'] = true
    run_measure_in_workflow(test_name, test_model_path, args_hash)
  end

  def test_run_measure
    # create an instance of the measure
    measure = ReduceInsightOutput.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = "#{File.dirname(__FILE__)}/example_model.osm"
    model = translator.loadModel(path)
    refute_empty(model)
    model = model.get

    model.setWorkflowJSON(osw)

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash['suppress_files'] = true
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert_equal(1, result.stepInfo.size)
    assert_empty(result.stepWarnings)

    # check that there is now 1 extra space
    assert_equal(0, model.getOutputVariables.size)
    assert_equal(0, model.getOutputMeters.size)

    puts osw.string
    assert(osw.runOptions.get.skipEnergyPlusPreprocess)
    assert(osw.runOptions.get.skipZipResults)
    assert(osw.runOptions.get.forwardTranslatorOptions.excludeLCCObjects)
    assert(osw.runOptions.get.forwardTranslatorOptions.excludeHTMLOutputReport)

    # save the model to test output directory
    output_file_path = "#{File.dirname(__FILE__)}/output/test_output.osm"
    model.save(output_file_path, true)
  end
end
