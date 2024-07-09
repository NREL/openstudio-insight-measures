require_relative '../minitest_helper'

class ACVRFFactoryTest < MiniTest::Unit::TestCase
  def test_add_hvac_system
    # setup - data
    acvrf_factory = ACVRFFactory.new
    standard = Minitest::Mock.new
    model = Object.new
    conditioned_zones = Object.new
    zones_by_story = [Object.new, Object.new]

    # setup - expectations
    standard.expect :model_remove_prm_hvac, nil, [model]
    standard.expect :model_assign_spaces_to_stories, nil, [model]
    standard.expect :model_group_zones_by_story, zones_by_story, [model, conditioned_zones]
    standard.expect :model_add_doas, nil,[model,
                                          conditioned_zones,
                                          hot_water_loop: nil,
                                          chilled_water_loop: nil,
                                          doas_type: 'DOASVAV',
                                          demand_control_ventilation: true]

    zones_by_story.each do |zones|
      standard.expect :model_add_vrf, nil, [
          model, zones
      ]
    end

    # exercise
    OSHelper.stub :get_conditioned_zones, conditioned_zones do
      acvrf_factory.add_hvac_system(model, standard)
    end

    # verify
    assert_mock(standard)
  end
end