class FactoryProducer
  def self.get_factory(hvac_type)
    case hvac_type
    when 'PTAC'
      PTACFactory.new
    when 'PTHP'
      PTHPFactory.new
    when 'PVAV'
      PVAVFactory.new
    when 'VAV'
      VAVFactory.new
    when 'FPFC + DOAS'
      FPFCFactory.new
    when 'ACVRF + DOAS'
      ACVRFFactory.new
    end
  end
end