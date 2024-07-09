class FPFCFactory

  def add_hvac_system(model, standard)
    standard.model_remove_prm_hvac(model)

    conditioned_zones = OSHelper.get_conditioned_zones(model, standard)

    hw_loop = standard.model_add_hw_loop(model, 'NaturalGas',
                                         dsgn_sup_wtr_temp: 140,
                                         dsgn_sup_wtr_temp_delt: 30.0)

    cw_loop = standard.model_add_cw_loop(model,
                                         cooling_tower_type: 'Open Cooling Tower',
                                         cooling_tower_fan_type: 'Propeller or Axial',
                                         cooling_tower_capacity_control: 'TwoSpeed Fan',
                                         number_of_cells_per_tower: 1,
                                         number_cooling_towers: 1)

    chw_loop = standard.model_add_chw_loop(model,
                                           chw_pumping_type: 'const_pri_var_sec',
                                           dsgn_sup_wtr_temp: 44.0,
                                           dsgn_sup_wtr_temp_delt: 12.0,
                                           chiller_cooling_type: 'WaterCooled',
                                           condenser_water_loop: cw_loop)

    standard.model_add_doas(model,
                   conditioned_zones,
                   hot_water_loop: hw_loop,
                   chilled_water_loop: chw_loop,
                   doas_type: 'DOASVAV',
                   demand_control_ventilation: true)


    standard.model_add_four_pipe_fan_coil(model,
                                 conditioned_zones,
                                 chw_loop,
                                 hot_water_loop: hw_loop,
                                 ventilation: false)
  end
end