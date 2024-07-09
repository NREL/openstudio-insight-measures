class PTACFactory
  def add_hvac_system(model, standard)
    standard.model_remove_prm_hvac(model)
    conditioned_zones = OSHelper.get_conditioned_zones(model, standard)

    standard.model_add_ptac(model, conditioned_zones,
                            cooling_type: 'Single Speed DX AC')
  end
end