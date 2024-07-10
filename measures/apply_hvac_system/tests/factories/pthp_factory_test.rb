require_relative '../minitest_helper'

class PTHPFactoryTest < MiniTest::Unit::TestCase
  def test_add_hvac_system
    # setup - data
    pthp_factory = PTHPFactory.new
    standard = Minitest::Mock.new
    model = Object.new
    conditioned_zones = Object.new

    # setup - expectations
    standard.expect :model_remove_prm_hvac, nil, [model]
    standard.expect :model_add_pthp, nil, [model, conditioned_zones, fan_type: 'ConstantVolume']

    # exercise
    OSHelper.stub :get_conditioned_zones, conditioned_zones do
      pthp_factory.add_hvac_system(model, standard)
    end

    # verify
    assert_mock(standard)
  end
end