class OSHelper
  def self.get_conditioned_zones(model, standard)
    model.getThermalZones.select do |zone|
      OpenstudioStandards::ThermalZone.thermal_zone_heated?(zone) || OpenstudioStandards::ThermalZone.thermal_zone_cooled?(zone)
    end
  end
end