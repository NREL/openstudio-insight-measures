# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require "#{File.dirname(__FILE__)}/resources/os_lib_schedules"
require "#{File.dirname(__FILE__)}/resources/insight_temp_hoo"

# start the measure
class SetOperatingSchedules < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Set Operating Schedules'
  end

  # human readable description
  def description
    return 'This will alter existing schedules to mimic operations for 12 hours a day for 5, 6, or 7 days a week, as well as 24 hours for 7 days a week.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Code within the measure will infer the starting hours of operation, which will be used to manipulate the schedules.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make choice argument for facade
    choices = OpenStudio::StringVector.new
    choices << '12/5'
    choices << '12/6'
    choices << '12/7'
    choices << '24/7'
    choices << '24/7'
    choices << 'None' # will infer hoo and set but will not change other schedules
    op_hrs = OpenStudio::Measure::OSArgument.makeChoiceArgument('op_hrs', choices)
    op_hrs.setDisplayName('Operating Hours Choice')
    op_hrs.setDescription('Hours per day / Days per week')
    op_hrs.setDefaultValue('12/5')
    args << op_hrs

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
    op_hrs = runner.getStringArgumentValue('op_hrs', user_arguments)

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getScheduleRulesets.size} ruleset schedules.")

    # get hours of operation
    OsLibInsight.model_infer_hours_of_operation_building(model, invert_res: false,gen_occ_profile: true)

    # report back hours of operation
    hours_of_operation_hash = OsLibInsight.space_hours_of_operation(model.getSpaces.first)
    base_start_hoo = hours_of_operation_hash[-1][:hoo_start]
    base_finish_hoo = hours_of_operation_hash[-1][:hoo_end]
    base_length = hours_of_operation_hash[-1][:hoo_hours]
    runner.registerInfo("Based on default day building occupancy of initial model assuming initial hours of operation from #{base_start_hoo} to #{base_finish_hoo} hours.")

    if op_hrs == "None"
      runner.registerAsNotApplicable("Nothing was changed in the model other than hours of operation schedule being generated, it will not impact simulation results.")
      return true
    end

    # setup target days per week
    target_days = op_hrs.split("/").last.to_f

    # setup target hours of operation
    target_length = [op_hrs.split("/").first.to_f,24.0].min # issue with 24 in old method being used. This is working around.
    target_delta_length = target_length - base_length
    target_shift = target_delta_length / 2.0 # use this if want to hold start time constant and only expand into the evening
    runner.registerInfo("Duration of hours of operation for default profiles will be changed from #{base_length} hours to #{target_length} hours. The hours of operation will expand or contract equally in both directions.")

    # determine other adjust input method inputs
    inputs = {
        'base_start_hoo' => base_start_hoo,
        'base_finish_hoo' => base_finish_hoo,
        'delta_length_hoo' => target_delta_length,
        'shift_hoo' => 0.0,
        'default' => true,
        'mon' => true,
        'tue' => true,
        'wed' => true,
        'thur' => true,
        'fri' => true,
        'sat' => false,
        'sun' => false,
        'summer' => false,
        'winter' => false
    }

    # report behavior for days of the week
    days_of_week_to_remove = []
    if target_days == 7
      runner.registerInfo("Because operation for 7 days a week was requested schedule rules will be updated to exclude saturday and sunday. Saturday and sundays will use the default profile.")
    elsif target_days == 6
      runner.registerInfo("Because operation for 6 days a week was requested schedule rules will be updated to exclude saturday. Saturdays will use the default profile.")
      runner.registerInfo("Because operation for 6 days a week was requested schedule rules for sunday will be made that are representative non operating days.")
    else
      runner.registerInfo("Because operation for 5 days a week of was requested schedule rules for saturday and sunday will be made that are representative non operating days.")
    end

    # get a list of schedules used for thermostat cooling setpoint schedules
    cooling_setoint_schedules = []
    model.getThermostatSetpointDualSetpoints.each do |thermostat|
      clg_sch = thermostat.getCoolingSchedule
      if clg_sch.is_initialized
        cooling_setoint_schedules << clg_sch.get
      end
    end

    # edit schedules
    model.getScheduleRulesets.each do |schedule|

      # get min-max values
      if target_days < 7
        min_max = OsLib_Schedules.getMinMaxAnnualProfileValue(model, schedule)
        # use min value unless this schedule is used for thermostat cooling setpoint
        if cooling_setoint_schedules.uniq.include?(schedule)
          non_opp_val_target = min_max['max']
        else
          non_opp_val_target = min_max['min']
        end
      end

      # identify days of week that should have profiles made if they don't already exist
      if target_days == 7

        # disable sat sun in rules
        schedule.scheduleRules.each do |rule|
          rule.setApplySaturday(false)
          rule.setApplySunday(false)
        end
      elsif target_days == 6

        # disable sat om rules
        schedule.scheduleRules.each do |rule|
          rule.setApplySaturday(false)
        end

        # add sun(non opp)
        new_rule = OpenStudio::Model::ScheduleRule.new(schedule)
        new_rule.setApplySunday(true)
        new_rule.setName("#{schedule.name}_autogen_non_occ_vals")
        new_profile = new_rule.daySchedule
        time = OpenStudio::Time.new(0, 24, 0, 0) # value until
        new_profile.addValue(time,non_opp_val_target)

      else  # target days == 5

        # add sat and sun (non opp)
        new_rule = OpenStudio::Model::ScheduleRule.new(schedule)
        new_rule.setApplySaturday(true)
        new_rule.setApplySunday(true)
        new_rule.setName("#{schedule.name}_autogen_non_occ_vals")
        new_profile = new_rule.daySchedule
        time = OpenStudio::Time.new(0, 24, 0, 0) # value until
        new_profile.addValue(time,non_opp_val_target)

      end

      # shift and expand schedules
      OsLib_Schedules.adjust_hours_of_operation_for_schedule_ruleset(runner, model, schedule, inputs)

    end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getScheduleRulesets.size} ruleset schedules.")

    return true
  end
end

# register the measure to be used by the application
SetOperatingSchedules.new.registerWithApplication
