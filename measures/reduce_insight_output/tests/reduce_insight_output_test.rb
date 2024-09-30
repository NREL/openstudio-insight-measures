# insert your copyright here

require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'

require_relative '../measure'

class ReduceInsightOutputTest < Minitest::Test
  # def setup
  # end

  # def teardown
  # end

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
