require_relative 'minitest_helper'

class OSHelperTest < MiniTest::Unit::TestCase
  def test_get_conditioned_zones
    model = Minitest::Mock.new
    standard = Minitest::Mock.new
    conditioned_zone = Minitest::Mock.new
    unconditioned_zone = Minitest::Mock.new
    zones = [conditioned_zone, unconditioned_zone]

    model.expect :getThermalZones, zones
    standard.expect :thermal_zone_heated?, false, [conditioned_zone]
    standard.expect :thermal_zone_cooled?, true, [conditioned_zone]
    standard.expect :thermal_zone_heated?, false, [unconditioned_zone]
    standard.expect :thermal_zone_cooled?, false, [unconditioned_zone]

    conditioned_zones = OSHelper.get_conditioned_zones(model, standard)

    assert_equal(conditioned_zones, [conditioned_zone])
    assert_mock standard
    assert_mock model
  end
end