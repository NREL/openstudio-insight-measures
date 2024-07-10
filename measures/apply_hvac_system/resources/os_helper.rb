class OSHelper
  def self.get_conditioned_zones(model, standard)
    model.getThermalZones.select do |zone|
      standard.thermal_zone_heated?(zone) || standard.thermal_zone_cooled?(zone)
    end
  end
end