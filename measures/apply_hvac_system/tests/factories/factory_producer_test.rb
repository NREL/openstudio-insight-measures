require_relative '../minitest_helper'

class FactoryProducerTest < MiniTest::Unit::TestCase
  def test_get_factory_returns_ptac
    factory = FactoryProducer.get_factory('PTAC')

    assert_equal(factory.class, PTACFactory)
  end

  def test_get_factory_returns_pthp
    factory = FactoryProducer.get_factory('PTHP')

    assert_equal(factory.class, PTHPFactory)
  end

  def test_get_factory_returns_pvav
    factory = FactoryProducer.get_factory('PVAV')

    assert_equal(factory.class, PVAVFactory)
  end

  def test_get_factory_returns_vav
    factory = FactoryProducer.get_factory('VAV')

    assert_equal(factory.class, VAVFactory)
  end

  def test_get_factory_returns_fpfc_doas
    factory = FactoryProducer.get_factory('FPFC + DOAS')

    assert_equal(factory.class, FPFCFactory)
  end

  def test_get_factory_returns_acvrf_doas
    factory = FactoryProducer.get_factory('ACVRF + DOAS')

    assert_equal(factory.class, ACVRFFactory)
  end
end