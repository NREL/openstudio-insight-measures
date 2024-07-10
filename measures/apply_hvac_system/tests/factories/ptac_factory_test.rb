require_relative '../minitest_helper'

class PTACFactoryTest < MiniTest::Unit::TestCase
  def test_add_hvac_system
    # setup - data
    ptac_factory = PTACFactory.new
    standard = Minitest::Mock.new
    model = Object.new
    conditioned_zones = Object.new

    # setup - expectations
    standard.expect :model_remove_prm_hvac, nil, [model]
    standard.expect :model_add_ptac, nil, [model, conditioned_zones, cooling_type: 'Single Speed DX AC']

    # exercise
    OSHelper.stub :get_conditioned_zones, conditioned_zones do
      ptac_factory.add_hvac_system(model, standard)
    end

    # verify
    assert_mock(standard)
  end
end