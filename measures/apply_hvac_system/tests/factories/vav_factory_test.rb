require_relative '../minitest_helper'

class VAVFactoryTest < MiniTest::Unit::TestCase
  def test_add_hvac_system
    # setup - data
    vav_factory = VAVFactory.new
    standard = Minitest::Mock.new
    model = Object.new
    conditioned_zones = Object.new
    zones_by_story = [Object.new, Object.new]
    hw_loop = Object.new
    cw_loop = Object.new
    chw_loop = Object.new

    # setup - expectations
    standard.expect :model_remove_prm_hvac, nil, [model]
    standard.expect :model_assign_spaces_to_stories, nil, [model]
    standard.expect :model_group_zones_by_story, zones_by_story, [model, conditioned_zones]
    standard.expect :model_add_hw_loop, hw_loop, [model,
                                                  'NaturalGas',
                                                  dsgn_sup_wtr_temp: 140,
                                                  dsgn_sup_wtr_temp_delt: 30.0]
    standard.expect :model_add_cw_loop, cw_loop, [model,
                                                  cooling_tower_type: 'Open Cooling Tower',
                                                  cooling_tower_fan_type: 'Propeller or Axial',
                                                  cooling_tower_capacity_control: 'TwoSpeed Fan',
                                                  number_of_cells_per_tower: 1,
                                                  number_cooling_towers: 1]
    standard.expect :model_add_chw_loop, chw_loop, [model,
                                                   chw_pumping_type: 'const_pri_var_sec',
                                                   dsgn_sup_wtr_temp: 44.0,
                                                   dsgn_sup_wtr_temp_delt: 12.0,
                                                   chiller_cooling_type: 'WaterCooled',
                                                   condenser_water_loop: cw_loop]

    zones_by_story.each do |zones|
      standard.expect :model_add_vav_reheat, nil, [
          model, zones,
          reheat_type: 'Water',
          hot_water_loop: hw_loop,
          chilled_water_loop: chw_loop,
          fan_efficiency: 0.62,
          fan_motor_efficiency: 0.9,
          fan_pressure_rise: 4.0,
          econo_ctrl_mthd: 'DifferentialEnthalpy'
      ]
    end

    # exercise
    OSHelper.stub :get_conditioned_zones, conditioned_zones do
      vav_factory.add_hvac_system(model, standard)
    end

    # verify
    assert_mock(standard)
  end
end