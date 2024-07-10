class PVAVFactory
  def add_hvac_system(model, standard)
    standard.model_remove_prm_hvac(model)
    standard.model_assign_spaces_to_stories(model)
    conditioned_zones = OSHelper.get_conditioned_zones(model, standard)
    zones_by_story = standard.model_group_zones_by_story(model, conditioned_zones)

    hw_loop = standard.model_add_hw_loop(model, 'NaturalGas',
                                    dsgn_sup_wtr_temp: 140,
                                    dsgn_sup_wtr_temp_delt: 30.0)

    zones_by_story.each do |zone_group|
      standard.model_add_vav_reheat(model,
                             zone_group,
                             reheat_type: 'Water',
                             hot_water_loop: hw_loop,
                             fan_efficiency: 0.62,
                             fan_motor_efficiency: 0.9,
                             fan_pressure_rise: 4.0,
                             econo_ctrl_mthd: 'DifferentialEnthalpy')
    end
  end
end