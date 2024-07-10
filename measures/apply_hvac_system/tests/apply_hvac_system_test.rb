# insert your copyright here

require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require 'json'

require_relative '../measure.rb'
require_relative 'minitest_helper'

class ApplyHVACSystemTest < Minitest::Test
  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = ApplyHVACSystem.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(1, arguments.size)
    assert_equal('hvac_system', arguments[0].name)
  end

  def test_argument_choices
    measure = ApplyHVACSystem.new

    choices = ["ACVRF + DOAS", "PTAC", "VAV", "Radiant + DOAS", "FPFC + DOAS", "PTHP", "PVAV", "GSHP + DOAS"]

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(arguments[0].choiceValues, choices)
  end

  def test_ptac_integration
    measure = ApplyHVACSystem.new
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)
    model = OpenStudio::Model::Model.load(Config::OSM_FIXTURES + 'in.osm').get

    argument = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_system', ['PTAC'])
    argument.setValue('PTAC')
    argument_map = {"hvac_system"=> argument}
    measure.run(model, runner, argument_map)

    output_file_path = Config::OSM_OUTPUTS + "/ptac/in.osm"
    model.save(output_file_path, true)

    osw_in_path = Config::OSM_OUTPUTS + '/ptac/in.osw'
    cmd = "\"#{Config::CLI_PATH}\" run -w \"#{osw_in_path}\""
    assert(run_command(cmd))

    osw_out_path = Config::OSM_OUTPUTS + '/ptac/out.osw'
    osw_out = JSON.parse(File.read(osw_out_path))

    assert(osw_out['completed_status'] == 'Success')
  end

  def test_pthp_integration
    measure = ApplyHVACSystem.new
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)
    model = OpenStudio::Model::Model.load(Config::OSM_FIXTURES + 'in.osm').get

    argument = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_system', ['PTHP'])
    argument.setValue('PTHP')
    argument_map = {"hvac_system"=> argument}
    measure.run(model, runner, argument_map)

    output_file_path = Config::OSM_OUTPUTS + "/pthp/in.osm"
    model.save(output_file_path, true)

    osw_in_path = Config::OSM_OUTPUTS + '/pthp/in.osw'
    cmd = "\"#{Config::CLI_PATH}\" run -w \"#{osw_in_path}\""
    assert(run_command(cmd))

    osw_out_path = Config::OSM_OUTPUTS + '/pthp/out.osw'
    osw_out = JSON.parse(File.read(osw_out_path))

    assert(osw_out['completed_status'] == 'Success')
  end

  def test_pvav_integration
    measure = ApplyHVACSystem.new
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)
    model = OpenStudio::Model::Model.load(Config::OSM_FIXTURES + 'in.osm').get

    argument = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_system', ['PVAV'])
    argument.setValue('PVAV')
    argument_map = {"hvac_system"=> argument}
    measure.run(model, runner, argument_map)

    output_file_path = Config::OSM_OUTPUTS + "/pvav/in.osm"
    model.save(output_file_path, true)

    osw_in_path = Config::OSM_OUTPUTS + '/pvav/in.osw'
    cmd = "\"#{Config::CLI_PATH}\" run -w \"#{osw_in_path}\""
    assert(run_command(cmd))

    osw_out_path = Config::OSM_OUTPUTS + '/pvav/out.osw'
    osw_out = JSON.parse(File.read(osw_out_path))

    assert(osw_out['completed_status'] == 'Success')
  end

  def test_vav_integration
    measure = ApplyHVACSystem.new
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)
    model = OpenStudio::Model::Model.load(Config::OSM_FIXTURES + 'in.osm').get

    argument = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_system', ['VAV'])
    argument.setValue('VAV')
    argument_map = {"hvac_system"=> argument}
    measure.run(model, runner, argument_map)

    output_file_path = Config::OSM_OUTPUTS + "/vav/in.osm"
    model.save(output_file_path, true)

    osw_in_path = Config::OSM_OUTPUTS + '/vav/in.osw'
    cmd = "\"#{Config::CLI_PATH}\" run -w \"#{osw_in_path}\""
    assert(run_command(cmd))

    osw_out_path = Config::OSM_OUTPUTS + '/vav/out.osw'
    osw_out = JSON.parse(File.read(osw_out_path))

    assert(osw_out['completed_status'] == 'Success')
  end

  def test_fpfc_doas_integration
    measure = ApplyHVACSystem.new
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)
    model = OpenStudio::Model::Model.load(Config::OSM_FIXTURES + 'in.osm').get

    argument = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_system', ['FPFC + DOAS'])
    argument.setValue('FPFC + DOAS')
    argument_map = {"hvac_system"=> argument}
    measure.run(model, runner, argument_map)

    output_file_path = Config::OSM_OUTPUTS + "fpfc_doas/in.osm"
    model.save(output_file_path, true)

    osw_in_path = Config::OSM_OUTPUTS + 'fpfc_doas/in.osw'
    cmd = "\"#{Config::CLI_PATH}\" run -w \"#{osw_in_path}\""
    assert(run_command(cmd))

    osw_out_path = Config::OSM_OUTPUTS + '/fpfc_doas/out.osw'
    osw_out = JSON.parse(File.read(osw_out_path))

    assert(osw_out['completed_status'] == 'Success')
  end

  def test_acvrf_doas_integration
    measure = ApplyHVACSystem.new
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)
    model = OpenStudio::Model::Model.load(Config::OSM_FIXTURES + 'in.osm').get

    argument = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_system', ['ACVRF + DOAS'])
    argument.setValue('ACVRF + DOAS')
    argument_map = {"hvac_system"=> argument}
    measure.run(model, runner, argument_map)

    output_file_path = Config::OSM_OUTPUTS + "acvrf_doas/in.osm"
    model.save(output_file_path, true)

    osw_in_path = Config::OSM_OUTPUTS + 'acvrf_doas/in.osw'
    cmd = "\"#{Config::CLI_PATH}\" run -w \"#{osw_in_path}\""
    assert(run_command(cmd))

    osw_out_path = Config::OSM_OUTPUTS + 'acvrf_doas/out.osw'
    osw_out = JSON.parse(File.read(osw_out_path))

    assert(osw_out['completed_status'] == 'Success')
  end
end
