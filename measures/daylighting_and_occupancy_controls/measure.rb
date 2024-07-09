# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# load OpenStudio measure libraries
require "#{File.dirname(__FILE__)}/resources/os_lib_schedules"
require 'openstudio-standards'

# start the measure
class DaylightingAndOccupancyControls < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Daylighting and Occupancy Controls'
  end

  # human readable description
  def description
    return 'Have option for none, daylighting, occupancy, or both.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Daylighting controls will physically add in daylighting controls to spaces in the building, while occupancy control will alter lighting and plug load schedules'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make choice argument for choice
    choices = OpenStudio::StringVector.new
    choices << 'None'
    choices << 'Daylighting Controls'
    choices << 'Occupancy Controls'
    choices << 'Daylighting and Occupancy Controls'
    choice = OpenStudio::Measure::OSArgument.makeChoiceArgument('choice', choices, true)
    choice.setDisplayName('Daylighting and Occupancy Control Strategy.')
    choice.setDefaultValue('Daylighting and Occupancy Controls')
    args << choice

    # make choice argument for facade
    choices = OpenStudio::StringVector.new
    choices << '90.1-2010'
    choices << '90.1-2013'
    template = OpenStudio::Measure::OSArgument.makeChoiceArgument('template', choices, true)
    template.setDisplayName('Template')
    template.setDescription('Changes how daylighting controls are applied.')
    template.setDefaultValue('90.1-2013')
    args << template

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
    choice = runner.getStringArgumentValue('choice', user_arguments)
    template = runner.getStringArgumentValue('template', user_arguments)

    # report initial condition of model
    # todo - extend initial and final to report avg fractional lighting and equip schedule values
    runner.registerInitialCondition("The building started with #{model.getDaylightingControls.size} daylighting control objects.")

    # setup flags
    daylighting_ctrls = false
    occupancy_ctrls = false
    if choice == "Daylighting Controls"
      daylighting_ctrls = true
    elsif choice == "Occupancy Controls"
      occupancy_ctrls = true
    elsif choice == "Daylighting and Occupancy Controls"
      daylighting_ctrls = true
      occupancy_ctrls = true
    else
      # remove any existing daylight controls
      if model.getDaylightingControls.size > 0
        runner.registerInfo("None was selected. Removing #{model.getDaylightingControls.size} daylighting control objects from the model. Cannot infer occupancy controls.")
        model.getDaylightingControls.each do |control|
          control.remove
        end
      else
        runner.registerAsNotApplicable("None was selected and there are no daylighting control objects to remove from the initial model. Cannot infer occupancy controls.")
        return true
      end
    end

    # add daylighting_ctrls
    if daylighting_ctrls

      # todo - confirm behavior if space alrady has daylight control
      standard = Standard.build(template)
      standard.model_add_daylighting_controls(model)

      runner.registerInfo("Adding dayligting controls to selected spaes in model as specified by ASHRAE #{template}.")
    end

    # apply occupancy_ctrls
    if occupancy_ctrls

      # gather schedules to alter
      # todo - enhance to edit clone of schedule if schedule is used on non light and plug load objects
      schedules = []
      multiplier_val = 0.9

      # loop through lights and plug loads that are used in the model to populate schedule hash
      model.getLightss.each do |light|

        # check if this instance is used in the model
        if light.spaceType.is_initialized
          next if light.spaceType.get.spaces.size == 0
        end

        # find schedule
        if light.schedule.is_initialized && light.schedule.get.to_ScheduleRuleset.is_initialized
          schedules << light.schedule.get.to_ScheduleRuleset.get
        else
          runner.registerWarning("#{light.name} does not have a schedule or schedule is not a schedule ruleset assigned and could not be altered")
        end
      end

      runner.registerInfo("Adding occupancy controls to model by altering #{schedules.uniq.size} lighting and plug load schedules.")
      # loop through and alter schedules
      schedules.uniq.each do |sch|
        OsLib_Schedules.simpleScheduleValueAdjust(model, sch,multiplier_val,"Multiplier")
      end

    end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getDaylightingControls.size} daylighting control objects.")

    return true
  end
end

# register the measure to be used by the application
DaylightingAndOccupancyControls.new.registerWithApplication
