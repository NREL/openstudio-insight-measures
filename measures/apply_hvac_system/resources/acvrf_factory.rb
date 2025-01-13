class ACVRFFactory
  def add_hvac_system(model, standard)
    standard.model_remove_prm_hvac(model)
    OpenstudioStandards::Geometry.model_assign_spaces_to_building_stories(model)
    conditioned_zones = OSHelper.get_conditioned_zones(model, standard)
    zones_by_story = OpenstudioStandards::Geometry.model_group_thermal_zones_by_building_story(model, conditioned_zones)

    standard.model_add_doas(model,
                            conditioned_zones,
                            hot_water_loop: nil,
                            chilled_water_loop: nil,
                            doas_type: 'DOASVAV',
                            demand_control_ventilation: true)

    zones_by_story.each do |zone_group|
      standard.model_add_vrf(model,
                             zone_group)
    end

  end
end