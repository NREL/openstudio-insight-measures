require_relative 'apply_hvac_system'

class ApplyHVACSystem < OpenStudio::Measure::ModelMeasure
  require 'openstudio-standards'
  require 'rexml/document'
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Apply HVAC System'
  end

  # human readable description
  def description
    return ''
  end

  # human readable description of modeling approach
  def modeler_description
    return ''
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # the name of the space to add to the model
    choices = OpenStudio::StringVector.new
    choices << 'ACVRF + DOAS'
    choices << 'PTAC'
    choices << 'VAV'
    choices << 'Radiant + DOAS'
    choices << 'FPFC + DOAS'
    choices << 'PTHP'
    choices << 'PVAV'
    choices << 'GSHP + DOAS'
    hvac_system = OpenStudio::Measure::OSArgument.makeChoiceArgument('hvac_system', choices, true)
    hvac_system.setDisplayName('HVAC System')
    hvac_system.setDescription('This input determines the HVAC System to be applied')
    args << hvac_system

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    hvac_system = runner.getStringArgumentValue('hvac_system', user_arguments)

    standard = Standard.build('90.1-2013')
    factory = FactoryProducer.get_factory(hvac_system)
    if factory
      factory.add_hvac_system(model, standard)
      runner.registerWarning("adding HVAC system = #{hvac_system}")
    else
      OSHelper.get_conditioned_zones(model, standard).each do |zone|
        zone.setUseIdealAirLoads(true)
      end
    end

    # std.model_remove_prm_hvac(model)
    # std.model_assign_spaces_to_stories(model)
    # conditioned_zones = model.getThermalZones.select {|zone| std.thermal_zone_heated?(zone) || std.thermal_zone_cooled?(zone)}
    # zones_by_story = std.model_group_zones_by_story(model, conditioned_zones)
    #

    # when "Radiant + DOAS"
    #   hw_loop = std.model_add_hw_loop(model, 'NaturalGas',
    #                                   dsgn_sup_wtr_temp: 120,
    #                                   dsgn_sup_wtr_temp_delt: 10.0)
    #
    #   cw_loop = std.model_add_cw_loop(model,
    #                                   cooling_tower_type: 'Open Cooling Tower',
    #                                   cooling_tower_fan_type: 'Propeller or Axial',
    #                                   cooling_tower_capacity_control: 'TwoSpeed Fan',
    #                                   number_of_cells_per_tower: 1,
    #                                   number_cooling_towers: 1)
    #
    #   chw_loop = std.model_add_chw_loop(model,
    #                                     chw_pumping_type: 'const_pri_var_sec',
    #                                     dsgn_sup_wtr_temp: 57.0,
    #                                     dsgn_sup_wtr_temp_delt: 6.0,
    #                                     chiller_cooling_type: 'WaterCooled',
    #                                     condenser_water_loop: cw_loop)
    #
    #   # std.model_add_low_temp_radiant(model, conditioned_zones hw_loop, chw_loop)
    # when "GSHP + DOAS"
    #   std.model_add_hvac_system(model, 'Ground Source Heat Pumps with DOAS with DCV', 'Electricity', nil, 'Electricity', conditioned_zones,
    #                             air_loop_heating_type: "DX",
    #                             air_loop_cooling_type: "DX")
    # when "ACVRF + DOAS"
    #   zones_by_story.each do |zone_group|
    #     std.model_add_vrf(model, zone_group)
    #   end
    #
    #   std.model_add_doas(model, conditioned_zones,
    #                      hot_water_loop: hw_loop,
    #                      chilled_water_loop: chw_loop,
    #                      doas_type: 'DOASVAV',
    #                      demand_control_ventilation: true)

  end

  def get_conditioned_zones(model, xml)
    conditioned_thermal_zones = []
    unconditioned_zone_cad_object_ids = get_unconditioned_zone_cad_object_ids(xml)

    model.getThermalZones.each do |zone|
      cad_object_id = zone.additionalProperties.getFeatureAsString('CADObjectId')
      if cad_object_id.is_initialized and !unconditioned_zone_cad_object_ids.include? cad_object_id.get
        conditioned_thermal_zones << zone
      end
    end

    conditioned_thermal_zones
  end

  def get_thermal_zone_by_cad_object_id(model, cad_object_id)
    model.getThermalZones.each do |thermal_zone|
      feature = thermal_zone.additionalProperties.getFeatureAsString('CADObjectId')
      if feature.is_initialized and feature.get == cad_object_id
        return thermal_zone
      end
    end
    return false
  end

  def get_unconditioned_zone_cad_object_ids(xml)
    unconditioned_ids = get_unconditioned_zone_hvac_equipment_ids(xml)
    unconditioned_cad_object_ids = []

    xml.get_elements('gbXML/Zone').each do |zone|
      zone_hvac_equipment_id = zone.elements['ZoneHVACEquipmentId']

      if zone_hvac_equipment_id
        id = zone_hvac_equipment_id.attributes['zoneHVACEquipmentIdRef']
        if unconditioned_ids.include? id
          unconditioned_cad_object_ids << zone.elements['CADObjectId'].text
        end
      end

    end

    unconditioned_cad_object_ids
  end

  def get_unconditioned_zone_hvac_equipment_ids(xml)
    ids = []

    xml.get_elements('gbXML/ZoneHVACEquipment').each do |equipment|
      if equipment.attributes['zoneHVACEquipmentType'] == 'UnConditioned'
        ids << equipment.attributes['id']
      end
    end

    return ids

  end
end

# register the measure to be used by the application
ApplyHVACSystem.new.registerWithApplication
