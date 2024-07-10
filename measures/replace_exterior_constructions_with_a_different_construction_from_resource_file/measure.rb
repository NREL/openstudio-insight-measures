# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class ReplaceExteriorConstructionsWithADifferentConstructionFromResourceFile < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Replace Exterior Constructions with a Different Construction from Resource File'
  end

  # human readable description
  def description
    return 'Replace exterior wall, roof, or window constructions, with construction from a resource file.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'This will only have an argument for target construction. How that construction is tagged in the resource file will determine which surface types the construction is applied to.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    #make a choice argument for constructions
    construction_handles = OpenStudio::StringVector.new
    construction_display_names = OpenStudio::StringVector.new

    #load construction library
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/resources/insight_constructions.osm")
    model2 = translator.loadModel(path)
    model2 = model2.get

    #putting constructions into hash
    construction_args = model2.getConstructions
    construction_args_hash = {}
    construction_args.each do |construction_arg|
      construction_args_hash[construction_arg.name.to_s] = construction_arg
    end

    #looping through sorted hash of model objects
    construction_args_hash.sort.map do |key,value|
      construction_handles << value.handle.to_s
      construction_display_names << key
    end

    #make a choice argument for new construction
    new_construction = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("new_construction", construction_handles, construction_display_names,true)
    new_construction.setDisplayName("Target Construction for Exterior Surface Replacement")
    args << new_construction

    # make choice argument for facade
    # generally "All" should be used when a roof construction is picked and there are flat roofs.
    choices = OpenStudio::StringVector.new
    choices << 'North'
    choices << 'East'
    choices << 'South'
    choices << 'West'
    choices << 'All'
    facade = OpenStudio::Measure::OSArgument.makeChoiceArgument('facade', choices, true)
    facade.setDisplayName('Cardinal Direction.')
    facade.setDescription('Constructions will be applied to the specified facade or facades.')
    facade.setDefaultValue('All')
    args << facade

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # load resources model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/resources/insight_constructions.osm")
    model2 = translator.loadModel(path)
    model2 = model2.get

    #assign the user inputs to variables
    new_construction = runner.getOptionalWorkspaceObjectChoiceValue("new_construction", user_arguments, model2)
    facade = runner.getStringArgumentValue('facade', user_arguments)

    #check the new construction for reasonableness
    if new_construction.empty?
      handle = runner.getStringArgumentValue("new_construction", user_arguments)
      if handle.empty?
        runner.registerError("No construction was chosen.")
      else
        runner.registerError("The selected construction with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not new_construction.get.to_Construction.empty?
        new_construction = new_construction.get.to_Construction.get
      else
        runner.registerError("Script Error - argument not showing up as construction.")
        return false
      end
    end

    # clone construction into model
    if not model2.getConstructionByName(new_construction.name.to_s).is_initialized
      runner.registerError('Did not find the expected construction in library.')
      return false
    end
    selected_construction = model2.getConstructionByName(new_construction.name.to_s).get
    new_construction = selected_construction.clone(model).to_Construction.get

    # identify construction type selected
    if new_construction.standardsInformation.intendedSurfaceType.is_initialized
      const_int_use = new_construction.standardsInformation.intendedSurfaceType.get
    else
      runner.registerError("Selected construction named #{new_construction.name} is not tagged with and intended surface type and cannot be applied to surfaces in the model.")
      return false
    end

    # report choice and store variable
    runner.registerInfo("Selected #{new_construction.name}, #{const_int_use}")
    surf_type = nil
    sub_surf_type = []
    if const_int_use == "ExteriorWall"
      surf_type = "Wall"
    elsif const_int_use == "ExteriorRoof"
      surf_type = "RoofCeiling"
    elsif const_int_use == "ExteriorWindow"
      sub_surf_type = ["FixedWindow","OperableWindow"] # GlassDoor?
    else
      runner.registerError("Selected construction named #{new_construction.name} tag of #{const_int_use} is not expected by this measure.")
      return false
    end

    # store initial constructions used
    ext_constructions = []
    if !surf_type.nil?
      # loop through surfaces
      model.getSurfaces.each do |surface|
        next if not surface.outsideBoundaryCondition == "Outdoors"
        next if not surface.surfaceType == surf_type

        # get the absoluteAzimuth for the surface so we can categorize it
        absoluteAzimuth = OpenStudio.convert(surface.azimuth, 'rad', 'deg').get + surface.space.get.directionofRelativeNorth + model.getBuilding.northAxis
        absoluteAzimuth -= 360.0 until absoluteAzimuth < 360.0

        if facade == 'North'
          next if !((absoluteAzimuth >= 315.0) || (absoluteAzimuth < 45.0))
        elsif facade == 'East'
          next if !((absoluteAzimuth >= 45.0) && (absoluteAzimuth < 135.0))
        elsif facade == 'South'
          next if !((absoluteAzimuth >= 135.0) && (absoluteAzimuth < 225.0))
        elsif facade == 'West'
          next if !((absoluteAzimuth >= 225.0) && (absoluteAzimuth < 315.0))
        elsif facade == 'All'
          # keep going
        else
          runner.registerError('Unexpected value of facade: ' + facade + '.')
          return false
        end

        # store original construction and clear out
        if surface.construction.is_initialized
          ext_constructions << surface.construction.get.name.to_s
          if facade == "All"
            surface.resetConstruction
          else
            surface.setConstruction(new_construction)
          end
        else
          ext_constructions << "NA"
          if !facade == "All"
            surface.setConstruction(new_construction)
          end
        end
      end
    else
      # loop through sub surfaces
      model.getSubSurfaces.each do |sub_surface|
        next if not sub_surface.outsideBoundaryCondition == "Outdoors"
        next if not sub_surf_type.include?(sub_surface.subSurfaceType)

        # get the absoluteAzimuth for the surface so we can categorize it
        absoluteAzimuth = OpenStudio.convert(sub_surface.azimuth, 'rad', 'deg').get + sub_surface.surface.get.space.get.directionofRelativeNorth + model.getBuilding.northAxis
        absoluteAzimuth -= 360.0 until absoluteAzimuth < 360.0

        if facade == 'North'
          next if !((absoluteAzimuth >= 315.0) || (absoluteAzimuth < 45.0))
        elsif facade == 'East'
          next if !((absoluteAzimuth >= 45.0) && (absoluteAzimuth < 135.0))
        elsif facade == 'South'
          next if !((absoluteAzimuth >= 135.0) && (absoluteAzimuth < 225.0))
        elsif facade == 'West'
          next if !((absoluteAzimuth >= 225.0) && (absoluteAzimuth < 315.0))
        elsif facade == 'All'
          # keep going
        else
          runner.registerError('Unexpected value of facade: ' + facade + '.')
          return false
        end

        # store original construction and clear out
        if sub_surface.construction.is_initialized
          ext_constructions << sub_surface.construction.get.name.to_s
          if facade == "All"
            sub_surface.resetConstruction
          else
            sub_surface.setConstruction(new_construction)
          end
        else
          ext_constructions << "NA"
          if !facade == "All"
            sub_surface.setConstruction(new_construction)
          end
        end
      end
    end

    # report initial condition of model
    if facade == "All"
      runner.registerInitialCondition("The building initially used the following constructions for #{const_int_use} surfaces: #{ext_constructions.uniq.sort.join(",")}.")
    else
      runner.registerInitialCondition("The building initially used the following constructions for #{const_int_use} surfaces on the #{facade} facade: #{ext_constructions.uniq.sort.join(",")}.")
    end

    # when all facades being changed constructions are assigned to construction sets instead of individual surfaces
    if facade == "All"

      # remove this surface type from any other construction sets
      model.getDefaultConstructionSets.each do |default_construction_sets|
        if !surf_type.nil?
          if default_construction_sets.defaultExteriorSurfaceConstructions.is_initialized
            ext_surf_set = default_construction_sets.defaultExteriorSurfaceConstructions.get
            if surf_type == "Wall"
              ext_surf_set.resetWallConstruction
            elsif surf_type == "RoofCeiling"
              ext_surf_set.resetRoofCeilingConstruction
            end
          end
        else
          if default_construction_sets.defaultExteriorSubSurfaceConstructions.is_initialized
            ext_sub_surf_set = default_construction_sets.defaultExteriorSubSurfaceConstructions.get
            ext_sub_surf_set.resetFixedWindowConstruction
            ext_sub_surf_set.resetOperableWindowConstruction
            # keep in sync with array for sub_surf_type, currently GlassDoor insn't included
          end
        end
      end

      # create or find default construction set assigned to the building
      if model.getBuilding.defaultConstructionSet.is_initialized
        bldg_default_const_set = model.getBuilding.defaultConstructionSet.get
      else
        bldg_default_const_set = OpenStudio::Model::DefaultConstructionSet.new(model)
        model.getBuilding.setDefaultConstructionSet(bldg_default_const_set)
      end

      # set properties for default surfaces and sub-surfaces
      if !surf_type.nil?
        if bldg_default_const_set.defaultExteriorSurfaceConstructions.is_initialized
          ext_surf_set = bldg_default_const_set.defaultExteriorSurfaceConstructions.get
        else
          ext_surf_set = OpenStudio::Model::DefaultSurfaceConstructions.new(model)
          bldg_default_const_set.setDefaultExteriorSurfaceConstructions(ext_surf_set)
        end
        if surf_type == "Wall"
          ext_surf_set.setWallConstruction(new_construction)
        elsif surf_type == "RoofCeiling"
          ext_surf_set.setRoofCeilingConstruction(new_construction)
        end
      else
        if bldg_default_const_set.defaultExteriorSubSurfaceConstructions.is_initialized
          ext_sub_surf_set = bldg_default_const_set.defaultExteriorSubSurfaceConstructions.get
        else
          ext_sub_surf_set = OpenStudio::Model::DefaultSubSurfaceConstructions.new(model)
          bldg_default_const_set.setDefaultExteriorSubSurfaceConstructions(ext_sub_surf_set)
        end
        ext_sub_surf_set.setFixedWindowConstruction(new_construction)
        ext_sub_surf_set.setOperableWindowConstruction(new_construction)
        # keep in sync with array for sub_surf_type, currently GlassDoor insn't included
      end

    end

    # store constructions for final model
    final_ext_constructions = []
    if !surf_type.nil?
      # loop through surfaces
      model.getSurfaces.each do |surface|
        next if not surface.outsideBoundaryCondition == "Outdoors"
        next if not surface.surfaceType == surf_type

        # get the absoluteAzimuth for the surface so we can categorize it
        absoluteAzimuth = OpenStudio.convert(surface.azimuth, 'rad', 'deg').get + surface.space.get.directionofRelativeNorth + model.getBuilding.northAxis
        absoluteAzimuth -= 360.0 until absoluteAzimuth < 360.0

        if facade == 'North'
          next if !((absoluteAzimuth >= 315.0) || (absoluteAzimuth < 45.0))
        elsif facade == 'East'
          next if !((absoluteAzimuth >= 45.0) && (absoluteAzimuth < 135.0))
        elsif facade == 'South'
          next if !((absoluteAzimuth >= 135.0) && (absoluteAzimuth < 225.0))
        elsif facade == 'West'
          next if !((absoluteAzimuth >= 225.0) && (absoluteAzimuth < 315.0))
        elsif facade == 'All'
          # keep going
        else
          runner.registerError('Unexpected value of facade: ' + facade + '.')
          return false
        end

        # store original construction and clear out
        if surface.construction.is_initialized
          final_ext_constructions << surface.construction.get.name.to_s
        else
          final_ext_constructions << "NA"
        end
      end
    else
      # loop through sub surfaces
      model.getSubSurfaces.each do |sub_surface|
        next if not sub_surface.outsideBoundaryCondition == "Outdoors"
        next if not sub_surf_type.include?(sub_surface.subSurfaceType)

        # get the absoluteAzimuth for the surface so we can categorize it
        absoluteAzimuth = OpenStudio.convert(sub_surface.azimuth, 'rad', 'deg').get + sub_surface.space.get.directionofRelativeNorth + model.getBuilding.northAxis
        absoluteAzimuth -= 360.0 until absoluteAzimuth < 360.0

        if facade == 'North'
          next if !((absoluteAzimuth >= 315.0) || (absoluteAzimuth < 45.0))
        elsif facade == 'East'
          next if !((absoluteAzimuth >= 45.0) && (absoluteAzimuth < 135.0))
        elsif facade == 'South'
          next if !((absoluteAzimuth >= 135.0) && (absoluteAzimuth < 225.0))
        elsif facade == 'West'
          next if !((absoluteAzimuth >= 225.0) && (absoluteAzimuth < 315.0))
        elsif facade == 'All'
          # keep going
        else
          runner.registerError('Unexpected value of facade: ' + facade + '.')
          return false
        end

        # store original construction and clear out
        if sub_surface.construction.is_initialized
          final_ext_constructions << sub_surface.construction.get.name.to_s
        else
          final_ext_constructions << "NA"
        end
      end
    end

    # report final condition of model
    if facade == "All"
      runner.registerFinalCondition("The final building uses the following constructions for #{const_int_use} surfaces: #{final_ext_constructions.uniq.sort.join(",")}.")
    else
      runner.registerFinalCondition("The final building uses the following constructions for #{const_int_use} surfaces on the #{facade} facade: #{final_ext_constructions.uniq.sort.join(",")}.")
    end

    return true
  end
end

# register the measure to be used by the application
ReplaceExteriorConstructionsWithADifferentConstructionFromResourceFile.new.registerWithApplication
