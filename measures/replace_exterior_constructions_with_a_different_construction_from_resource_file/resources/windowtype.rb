require 'oga'

class SolarHeatGainCoeff
  attr_accessor :value, :unit, :solar_incident_angle

  def initialize(value:, unit:, solar_incident_angle: nil)
    @value = value
    @unit = unit
    @solar_incident_angle = solar_incident_angle
  end

  # Parse an XML element into a SolarHeatGainCoeff object
  def self.from_xml(xml_element)
    new(
      value: xml_element.text.to_f,
      unit: xml_element.get('unit'),
      solar_incident_angle: xml_element.get('solarIncidentAngle')&.to_f
    )
  end

end

class WindowType
  attr_accessor :id, :window_type_is_schematic, :doe_lib_id_ref, :program_id
  attr_accessor :name, :description, :u_value, :shading_coeff
  attr_accessor :solar_heat_gain_coeffs, :transmittances, :reflectances, :emittances
  attr_accessor :blinds, :frames, :gaps, :glazes, :costs, :ext_equip_id
  attr_accessor :full_name

  def initialize(id:, window_type_is_schematic: nil, doe_lib_id_ref: nil, program_id: nil)
    @id = id
    @window_type_is_schematic = window_type_is_schematic
    @doe_lib_id_ref = doe_lib_id_ref
    @program_id = program_id

    # Initialize collections for elements that allow multiple occurrences
    @solar_heat_gain_coeffs = []
    @transmittances = []
    @reflectances = []
    @emittances = []
    @blinds = []
    @frames = []
    @gaps = []
    @glazes = []
    @costs = []
  end

  # Parse an XML element into a WindowType object
  def self.from_xml(xml_element)
    window_type = new(
      id: xml_element.get('id'),
      window_type_is_schematic: xml_element.get('windowTypeIsSchematic') == 'true',
      doe_lib_id_ref: xml_element.get('DOELibIdRef'),
      program_id: xml_element.get('programId')
    )

    xml_element.children.each do |child|
      next unless child.is_a?(Oga::XML::Element)

      case child.name
      when 'Name'
        window_type.name = child.text
      when 'Description'
        window_type.description = child.text
      when 'U-value'
        window_type.u_value = child.text.to_f
      when 'ShadingCoeff'
        window_type.shading_coeff = child.text.to_f
      when 'SolarHeatGainCoeff'
        window_type.solar_heat_gain_coeffs << SolarHeatGainCoeff.from_xml(child)
      when 'Transmittance'
        window_type.transmittances << child.text.to_f
      when 'Reflectance'
        window_type.reflectances << child.text.to_f
      when 'Emittance'
        window_type.emittances << child.text.to_f
      when 'Blind'
        window_type.blinds << child.text
      when 'Frame'
        window_type.frames << child.text
      when 'Gap'
        window_type.gaps << child.text
      when 'Glaze'
        window_type.glazes << child.text
      when 'Cost'
        window_type.costs << child.text.to_f
      when 'ExtEquipId'
        window_type.ext_equip_id = child.text
      end
    end

    # full descriptive name
    window_type.full_name = window_type.name + " U-#{window_type.u_value.round(2)}"

    # overall shgc
    overall_shgc = window_type.solar_heat_gain_coeffs.select { |shgc| shgc.solar_incident_angle.nil? }.first.value
    window_type.full_name = 
      overall_shgc.nil? ?
      window_type.full_name :
      window_type.full_name + " SHGC-#{overall_shgc}"

    window_type
  end


end

# # Example usage
# xml_string = <<-XML
# <WindowType id="W001" windowTypeIsSchematic="true" DOELibIdRef="Library123" programId="Program001">
#   <Name>Example Window</Name>
#   <Description>An example window type</Description>
#   <U-value>1.2</U-value>
#   <ShadingCoeff>0.8</ShadingCoeff>
#   <SolarHeatGainCoeff unit="unitless" solarIncidentAngle="30">0.5</SolarHeatGainCoeff>
# </WindowType>
# XML

# # Parse the XML
# document = Oga.parse_xml(xml_string)
# window = WindowType.from_xml(document.at_xpath('WindowType'))

# # Inspect the object
# puts window.inspect

# window.solar_heat_gain_coeffs.each{|shgc| puts shgc.solar_incident_angle}


# path = "Constructions.xml"
# xml = Oga.parse_xml(File.read(path))
# windows = xml.xpath("//WindowType[@openingType='FixedWindow']")

# window_objs = []
# windows.each {|e| window_objs << WindowType.from_xml(e)}

# window_objs.each {|o| puts o.full_name}