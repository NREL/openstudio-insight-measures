class PTHPFactory
  def add_hvac_system(model, standard)
    standard.model_remove_prm_hvac(model)
    conditioned_zones = OSHelper.get_conditioned_zones(model, standard)

    standard.model_add_pthp(model, conditioned_zones,
                            fan_type: 'ConstantVolume')
  end
end