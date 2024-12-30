# insert your copyright here

require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require 'json'

require_relative '../measure.rb'
require_relative 'minitest_helper'

class ApplyHVACSystemTest < Minitest::Test

  def setup
    if !Dir.exist?(Config::OSM_OUTPUTS)
      FileUtils.mkdir(Config::OSM_OUTPUTS)
    end
  end

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

    assert_equal(8, model.getZoneHVACPackagedTerminalAirConditioners.size)

    output_file_dir = Config::OSM_OUTPUTS + 'ptac/'
    FileUtils.mkdir output_file_dir unless Dir.exist? output_file_dir
    output_file_path = File.join(output_file_dir, 'in.osm')
    model.save(output_file_path, true)

    osw_in_path = File.join(output_file_dir, 'in.osw')
    osw.setSeedFile(output_file_path)
    osw.setWeatherFile(Config::WEATHER + 'USA_MA_Boston-Logan.Intl.AP.725090_TMY3.epw')
    osw.saveAs(osw_in_path)

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

    assert_equal(8, model.getZoneHVACPackagedTerminalHeatPumps.size)

    output_file_dir = Config::OSM_OUTPUTS + 'pthp/'
    FileUtils.mkdir output_file_dir unless Dir.exist? output_file_dir
    output_file_path = File.join(output_file_dir, 'in.osm')
    model.save(output_file_path, true)

    osw_in_path = File.join(output_file_dir, 'in.osw')
    osw.setSeedFile(output_file_path)
    osw.setWeatherFile(Config::WEATHER + 'USA_MA_Boston-Logan.Intl.AP.725090_TMY3.epw')
    osw.saveAs(osw_in_path)
    
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

    assert_equal(8, model.getAirTerminalSingleDuctVAVReheats.size)
    assert_equal(3, model.getAirLoopHVACs.size)
    assert_equal(1, model.getPlantLoops.size)

    output_file_dir = Config::OSM_OUTPUTS + 'pvav/'
    FileUtils.mkdir output_file_dir unless Dir.exist? output_file_dir
    output_file_path = File.join(output_file_dir, 'in.osm')
    model.save(output_file_path, true)

    osw_in_path = File.join(output_file_dir, 'in.osw')
    osw.setSeedFile(output_file_path)
    osw.setWeatherFile(Config::WEATHER + 'USA_MA_Boston-Logan.Intl.AP.725090_TMY3.epw')
    osw.saveAs(osw_in_path)
    
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

    assert_equal(8, model.getAirTerminalSingleDuctVAVReheats.size)
    assert_equal(3, model.getAirLoopHVACs.size)
    assert_equal(3, model.getPlantLoops.size)

    output_file_dir = Config::OSM_OUTPUTS + 'vav/'
    FileUtils.mkdir output_file_dir unless Dir.exist? output_file_dir
    output_file_path = File.join(output_file_dir, 'in.osm')
    model.save(output_file_path, true)

    osw_in_path = File.join(output_file_dir, 'in.osw') 
    osw.setSeedFile(output_file_path)
    osw.setWeatherFile(Config::WEATHER + 'USA_MA_Boston-Logan.Intl.AP.725090_TMY3.epw')
    osw.saveAs(osw_in_path)

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

    assert_equal(8, model.getZoneHVACFourPipeFanCoils.size)
    assert_equal(8, model.getAirTerminalSingleDuctVAVNoReats)
    assert_equal(1, model.getAirLoopHVACs.size)
    assert_equal(3, model.getPlantLoops.size) 

    output_file_dir = Config::OSM_OUTPUTS + "fpfc_doas/"
    FileUtils.mkdir output_file_dir unless Dir.exist? output_file_dir
    output_file_path = File.join(output_file_dir, 'in.osm')
    model.save(output_file_path, true)

    osw_in_path = File.join(output_file_dir, 'in.osw') 
    osw.setSeedFile(output_file_path)
    osw.setWeatherFile(Config::WEATHER + 'USA_MA_Boston-Logan.Intl.AP.725090_TMY3.epw')
    osw.saveAs(osw_in_path)
    
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

    assert_equal(8, model.getZoneHVACTerminalUnitVariableRefrigerantFlows.size)
    assert_equal(8, model.getAirTerminalSingleDuctVAVNoReheats.size)
    assert_equal(1, model.getAirLoopHVACs.size)
    assert_equal(3, model.getAirConditionerVariableRefrigerantFlows.size)

    output_file_dir = Config::OSM_OUTPUTS + "acvrf_doas/"
    FileUtils.mkdir output_file_dir unless Dir.exist? output_file_dir
    output_file_path = File.join(output_file_dir, 'in.osm')
    model.save(output_file_path, true)

    osw_in_path = File.join(output_file_dir, 'in.osw') 
    osw.setSeedFile(output_file_path)
    osw.setWeatherFile(Config::WEATHER + 'USA_MA_Boston-Logan.Intl.AP.725090_TMY3.epw')
    osw.saveAs(osw_in_path)
    
    cmd = "\"#{Config::CLI_PATH}\" run -w \"#{osw_in_path}\""
    assert(run_command(cmd))

    osw_out_path = Config::OSM_OUTPUTS + 'acvrf_doas/out.osw'
    osw_out = JSON.parse(File.read(osw_out_path))

    assert(osw_out['completed_status'] == 'Success')
  end
end
