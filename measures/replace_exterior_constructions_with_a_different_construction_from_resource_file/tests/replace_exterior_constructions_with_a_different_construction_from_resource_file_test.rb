# insert your copyright here

require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class ReplaceExteriorConstructionsWithADifferentConstructionFromResourceFileTest < Minitest::Test

  def test_arg_names
    measure = ReplaceExteriorConstructionsWithADifferentConstructionFromResourceFile.new

    path = OpenStudio::Path.new(File.expand_path(File.dirname(__FILE__) + '/../resources/Constructions.xml'))
    xml_doc = File.read(path.to_s)
    parsed_xml = Oga.parse_xml(xml_doc)
    construction_names = parsed_xml.xpath("//Construction[@surfaceType='ExteriorWall' or @surfaceType='Roof']/Name").map(&:text)
    construction_names += parsed_xml.xpath("//WindowType[@openingType='FixedWindow']/Name").map(&:text)


    arguments = measure.arguments(OpenStudio::Model::Model.new)
    arguments_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)
    arg_choices = arguments_map['new_construction'].choiceValues

    assert_equal(arg_choices.size, construction_names.size)

  end

  def test_window_north
    test_construction_name = 'Double glazing - 1/8 in thick - clear/low-E (e = 0.1) glass'

    # create an instance of the measure
    measure = ReplaceExteriorConstructionsWithADifferentConstructionFromResourceFile.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = "#{File.dirname(__FILE__)}/example_model.osm"
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash['new_construction'] = test_construction_name
    args_hash['facade'] = 'North'
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
    #assert(result.info.size == 1)
    #assert(result.warnings.empty?)

    # find north windows
    north_windows = []
    non_north_windows = []
    model.getSubSurfaces.each do |sub_surf|
      absolute_azimuth = OpenStudio.convert(sub_surf.azimuth, 'rad', 'deg').get + sub_surf.surface.get.space.get.directionofRelativeNorth + model.getBuilding.northAxis
      absolute_azimuth -= 360.0 until absolute_azimuth < 360.0

      if ((absolute_azimuth >= 315.0) || (absolute_azimuth < 45.0))
        north_windows << sub_surf
      else
        non_north_windows << sub_surf
      end
    end 
    north_windows.each do |window|
      assert_equal(window.construction.get.name.get, test_construction_name + ' Construction')
    end
    non_north_windows.each do |window|
      refute_equal(window.construction.get.name.get, test_construction_name)
    end

    # save the model to test output directory
    output_file_path = "#{File.dirname(__FILE__)}//output/test_output.osm"
    model.save(output_file_path, true)
  end

  def test_window_all
    # create an instance of the measure
    measure = ReplaceExteriorConstructionsWithADifferentConstructionFromResourceFile.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = "#{File.dirname(__FILE__)}/example_model.osm"
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash['new_construction'] = 'Window Trp LoE'
    args_hash['facade'] = 'All'
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
    #assert(result.info.size == 1)
    #assert(result.warnings.empty?)

    # save the model to test output directory
    output_file_path = "#{File.dirname(__FILE__)}//output/test_output.osm"
    model.save(output_file_path, true)
  end

  def test_wall_special_char
    # create an instance of the measure
    measure = ReplaceExteriorConstructionsWithADifferentConstructionFromResourceFile.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = "#{File.dirname(__FILE__)}/example_model.osm"
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash['new_construction'] = 'Wall R13+R10 Metal'
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
    #assert(result.info.size == 1)
    #assert(result.warnings.empty?)

    # save the model to test output directory
    output_file_path = "#{File.dirname(__FILE__)}//output/test_output.osm"
    model.save(output_file_path, true)
  end

  def test_roof_special_char
    # create an instance of the measure
    measure = ReplaceExteriorConstructionsWithADifferentConstructionFromResourceFile.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = "#{File.dirname(__FILE__)}/example_model.osm"
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash['new_construction'] = 'Roof 10.25-inch SIP'
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
    #assert(result.info.size == 1)
    #assert(result.warnings.empty?)

    # save the model to test output directory
    output_file_path = "#{File.dirname(__FILE__)}//output/test_output.osm"
    model.save(output_file_path, true)
  end

end
