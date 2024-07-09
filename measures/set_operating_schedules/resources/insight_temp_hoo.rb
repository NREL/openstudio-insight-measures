
# this is a temporary library to make use of OpenStudio standards methods that are not in current OpenStudio installer, or are out of date with parametric schedule branch

module OsLibInsight

  require 'openstudio-standards'

  # This method looks at occupancy profiles for the building as a whole and generates an hours of operation default
  # schedule for the building. It also clears out any higher level hours of operation schedule assignments.
  # Spaces are organized by res and non_res. Whichever of the two groups has higher design level of people is used for building hours of operation
  # Resulting hours of operation can have as many rules as necessary to describe the operation.
  # Each ScheduleDay should be an on/off schedule with only values of 0 and 1. There should not be more than one on/off cycle per day.
  # In future this could create different hours of operation for residential vs. non-residential, by building type, story, or space type.
  # However this measure is a stop gap to convert old generic schedules to parametric schedules.
  # Future new schedules should be designed as paramtric from the start and would not need to run through this inference process
  #
  # @author David Goldwasser
  # @param model [Model]
  # @param fraction_of_daily_occ_range [Double] fraction above/below daily min range required to start and end hours of operation
  # @param invert_res [Bool] if true will reverse hours of operation for residential space types
  # @param gen_occ_profile [Bool] if true creates a merged occupancy schedule for diagnostic purposes. This schedule is added to the model but no specifically returned by this method
  # @return [ScheduleRuleset] schedule that is assigned to the building as default hours of operation
  def self.model_infer_hours_of_operation_building(model, fraction_of_daily_occ_range: 0.25, invert_res: true, gen_occ_profile: false)

    standard = Standard.build("90.1-2013")

    # create an array of non-residential and residential spaces
    res_spaces = []
    non_res_spaces = []
    res_people_design = 0
    non_res_people_design = 0
    model.getSpaces.each do |space|
      if standard.space_residential?(space)
        res_spaces << space
        res_people_design += space.numberOfPeople * space.multiplier
      else
        non_res_spaces << space
        non_res_people_design += space.numberOfPeople * space.multiplier
      end
    end
    OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.Model", "Model has design level of #{non_res_people_design} people in non residential spaces and #{res_people_design} people in residential spaces.")

    # create merged schedule for prevalent type (not used but can be generated for diagnostics)
    if gen_occ_profile
      res_prevalent = false
      if res_people_design > non_res_people_design
        occ_merged = spaces_get_occupancy_schedule(res_spaces, sch_name: "Calculated Occupancy Fraction Residential Merged")
        res_prevalent = true
      else
        occ_merged = spaces_get_occupancy_schedule(non_res_spaces, sch_name: "Calculated Occupancy Fraction NonResidential Merged")
      end
    end

    # re-run spaces_get_occupancy_schedule with x above min occupancy to create on/off schedule
    if res_people_design > non_res_people_design
      hours_of_operation = spaces_get_occupancy_schedule(res_spaces,
                                                         sch_name: "Building Hours of Operation Residential",
                                                         occupied_percentage_threshold: fraction_of_daily_occ_range,
                                                         threshold_calc_method: "normalized_daily_range")
      res_prevalent = true
    else
      hours_of_operation = spaces_get_occupancy_schedule(non_res_spaces,
                                                         sch_name: "Building Hours of Operation NonResidential",
                                                         occupied_percentage_threshold: fraction_of_daily_occ_range,
                                                         threshold_calc_method: "normalized_daily_range")
    end

    # remove gaps resulting in multiple on off cycles for each rule in schedule so it will be valid hours of operation
    profiles = []
    profiles << hours_of_operation.defaultDaySchedule
    hours_of_operation.scheduleRules.each do |rule|
      profiles << rule.daySchedule
    end
    profiles.each do |profile|
      times = profile.times
      values = profile.values
      next if times.size <= 3 # length of 1-3 should produce valid hours_of_operation profiles
      if values.first == 0 && values.last == 0
        wrap_dur_left_hr = time.totalHours
      else
        wrap_dur_left_hr = 0
      end
      occ_gap_hash = {}
      prev_time = 0
      prev_val = nil
      times.each_with_index do |time,i|
        next if time.totalHours == 0.0 # should not see this
        next if values[i] == prev_val # check if two 0 until time next to each other
        if values[i] == 0 # only store vacant segments
          if time.totalHours == 24 && ! wrap_dur_left_hr > 0
            occ_gap_hash[prev_time] = time.totalHours - prev_time + wrap_dur_left_hr
          else
            occ_gap_hash[prev_time] = time.totalHours - prev_time
          end
        end
        prev_time = time.totalHours
        prev_val = values[i]
      end
      profile.clearValues
      max_occ_gap_start = occ_gap_hash.key(occ_gap_hash.values.max)
      max_occ_gap_end_hr = max_occ_gap_start + occ_gap_hash[max_occ_gap_start] # can't add time and duration in hours
      if max_occ_gap_end_hr > 24.0 then max_occ_gap_end_hr -= 24.0 end

      # time for gap start
      target_start_hr = max_occ_gap_start.truncate
      target_start_min = ((max_occ_gap_start - target_start_hr) * 60.0).truncate
      max_occ_gap_start = OpenStudio::Time.new(0, target_start_hr, target_start_min, 0)

      # time for gap end
      target_end_hr = max_occ_gap_end_hr.truncate
      target_end_min = ((max_occ_gap_end_hr - target_end_hr) * 60.0).truncate
      max_occ_gap_end = OpenStudio::Time.new(0, target_end_hr, target_end_min, 0)

      profile.addValue(max_occ_gap_start,1)
      profile.addValue(max_occ_gap_end,0)
      os_time_24 = OpenStudio::Time.new(0, 24, 0, 0)
      if max_occ_gap_start > max_occ_gap_end
        profile.addValue(os_time_24,0)
      else
        profile.addValue(os_time_24,1)
      end
    end

    # reverse 1 and 0 values for res_prevalent building
    # currently spaces_get_occupancy_schedule doesn't use defaultDayProflie, so only inspecting rules for now.
    if invert_res && res_prevalent
      OpenStudio::logFree(OpenStudio::Info, "openstudio.Standards.Model", "Per argument passed in hours of operation are being inverted for buildings with more people in residential versus non-residential spaces.")
      hours_of_operation.scheduleRules.each do |rule|
        profile = rule.daySchedule
        times = profile.times
        values = profile.values
        profile.clearValues
        times.each_with_index do |time,i|
          orig_val = values[i]
          new_value = nil
          if orig_val == 0 then new_value = 1 end
          if orig_val == 1 then new_value = 0 end
          profile.addValue(time,new_value)
        end
      end
    end

    # set hours of operation for building level hours of operation
    model.getDefaultScheduleSets.each do |sch_set|
      sch_set.resetHoursofOperationSchedule
    end
    if model.getBuilding.defaultScheduleSet.is_initialized
      default_sch_set = model.getBuilding.defaultScheduleSet.get
    else
      default_sch_set = OpenStudio::Model::DefaultScheduleSet.new(model)
      default_sch_set.setName("Building Default Schedule Set")
      model.getBuilding.setDefaultScheduleSet(default_sch_set)
    end
    default_sch_set.setHoursofOperationSchedule(hours_of_operation)

    return hours_of_operation
  end

  # This method creates a new fractional schedule ruleset.
  # If occupied_percentage_threshold is set, this method will return a discrete on/off fractional schedule
  # with a value of one when occupancy across all spaces is greater than or equal to the occupied_percentage_threshold,
  # and zero all other times.  Otherwise the method will return the weighted fractional occupancy schedule.
  #
  # @param spaces [Array<OpenStudio::Model::Space>] array of spaces to generate occupancy schedule from
  # @param sch_name [String] the name of the generated occupancy schedule
  # @param occupied_percentage_threshold [Double] the minimum fraction (0 to 1) that counts as occupied
  #   if this parameter is set, the returned ScheduleRuleset will be 0 = unoccupied, 1 = occupied
  #   otherwise the ScheduleRuleset will be the weighted fractional occupancy schedule based on threshold_calc_method
  # @param threshold_calc_method [String] customizes behavior of occupied_percentage_threshold
  # fractional passes raw value through,
  # normalized_annual_range evaluates each value against the min/max range for the year
  # normalized_daily_range evaluates each value against the min/max range for the day.
  # The goal is a dynamic threshold that calibrates each day.
  # @return [<OpenStudio::Model::ScheduleRuleset>] a ScheduleRuleset of fractional or discrete occupancy
  # @todo Speed up this method.  Bottleneck is ScheduleRule.getDaySchedules
  def self.spaces_get_occupancy_schedule(spaces, sch_name: nil, occupied_percentage_threshold: nil, threshold_calc_method: "value")

    annual_normalized_tol = nil
    if threshold_calc_method == "normalized_annual_range"
      # run this method without threshold to get annual min and max
      temp_merged = spaces_get_occupancy_schedule(spaces)
      tem_min_max = schedule_ruleset_annual_min_max_value(temp_merged)
      annual_normalized_tol = tem_min_max['min'] + (tem_min_max['max'] - tem_min_max['min']) * occupied_percentage_threshold
      temp_merged.remove
    end

    # Get all the occupancy schedules in spaces.
    # Include people added via the SpaceType and hard-assigned to the Space itself.
    occ_schedules_num_occ = {}
    max_occ_in_spaces = 0
    spaces.each do |space|
      # From the space type
      if space.spaceType.is_initialized
        space.spaceType.get.people.each do |people|
          num_ppl_sch = people.numberofPeopleSchedule
          if num_ppl_sch.is_initialized
            num_ppl_sch = num_ppl_sch.get
            num_ppl_sch = num_ppl_sch.to_ScheduleRuleset
            next if num_ppl_sch.empty? # Skip non-ruleset schedules
            num_ppl_sch = num_ppl_sch.get
            num_ppl = people.getNumberOfPeople(space.floorArea)
            if occ_schedules_num_occ[num_ppl_sch].nil?
              occ_schedules_num_occ[num_ppl_sch] = num_ppl
            else
              occ_schedules_num_occ[num_ppl_sch] += num_ppl
            end
            max_occ_in_spaces += num_ppl
          end
        end
      end
      # From the space
      space.people.each do |people|
        num_ppl_sch = people.numberofPeopleSchedule
        if num_ppl_sch.is_initialized
          num_ppl_sch = num_ppl_sch.get
          num_ppl_sch = num_ppl_sch.to_ScheduleRuleset
          next if num_ppl_sch.empty? # Skip non-ruleset schedules
          num_ppl_sch = num_ppl_sch.get
          num_ppl = people.getNumberOfPeople(space.floorArea)
          if occ_schedules_num_occ[num_ppl_sch].nil?
            occ_schedules_num_occ[num_ppl_sch] = num_ppl
          else
            occ_schedules_num_occ[num_ppl_sch] += num_ppl
          end
          max_occ_in_spaces += num_ppl
        end
      end
    end

    unless sch_name.nil?
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Model', "Finding space schedules for #{sch_name}.")
    end
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Model', "The #{spaces.size} spaces have #{occ_schedules_num_occ.size} unique occ schedules.")
    occ_schedules_num_occ.each do |occ_sch, num_occ|
      OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Model', "...#{occ_sch.name} - #{num_occ.round} people")
    end
    OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Model', "   Total #{max_occ_in_spaces.round} people in #{spaces.size} spaces.")

    # For each day of the year, determine time_value_pairs = []
    year = spaces[0].model.getYearDescription
    yearly_data = []
    yearly_times = OpenStudio::DateTimeVector.new
    yearly_values = []
    (1..365).each do |i|
      times_on_this_day = []
      os_date = year.makeDate(i)
      day_of_week = os_date.dayOfWeek.valueName

      # Get the unique time indices and corresponding day schedules
      occ_schedules_day_schs = {}
      day_sch_num_occ = {}
      occ_schedules_num_occ.each do |occ_sch, num_occ|
        # Get the day schedules for this day
        # (there should only be one)
        day_schs = occ_sch.getDaySchedules(os_date, os_date)
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Model', "Schedule #{occ_sch.name} has #{day_schs.size} day schs") unless day_schs.size == 1
        day_schs[0].times.each do |time|
          times_on_this_day << time.toString
        end
        day_sch_num_occ[day_schs[0]] = num_occ
      end

      daily_normalized_tol = nil
      if threshold_calc_method == "normalized_daily_range"
        # pre-process day to get daily min and max
        daily_spaces_occ_frac = []
        times_on_this_day.uniq.sort.each do |time|
          os_time = OpenStudio::Time.new(time)
          os_date_time = OpenStudio::DateTime.new(os_date, os_time)
          # Total number of people at each time
          tot_occ_at_time = 0
          day_sch_num_occ.each do |day_sch, num_occ|
            occ_frac = day_sch.getValue(os_time)
            tot_occ_at_time += occ_frac * num_occ
          end
          # Total fraction for the spaces at each time
          daily_spaces_occ_frac << tot_occ_at_time / max_occ_in_spaces
          daily_normalized_tol = daily_spaces_occ_frac.min + (daily_spaces_occ_frac.max - daily_spaces_occ_frac.min) * occupied_percentage_threshold
        end
      end

      # Determine the total fraction for the spaces at each time
      daily_times = []
      daily_os_times = []
      daily_values = []
      daily_occs = []
      times_on_this_day.uniq.sort.each do |time|
        os_time = OpenStudio::Time.new(time)
        os_date_time = OpenStudio::DateTime.new(os_date, os_time)
        # Total number of people at each time
        tot_occ_at_time = 0
        day_sch_num_occ.each do |day_sch, num_occ|
          occ_frac = day_sch.getValue(os_time)
          tot_occ_at_time += occ_frac * num_occ
        end

        # Total fraction for the spaces at each time
        spaces_occ_frac = tot_occ_at_time / max_occ_in_spaces

        # If occupied_percentage_threshold is specified, schedule values are boolean
        # Otherwise use the actual spaces_occ_frac
        if occupied_percentage_threshold.nil?
          occ_status = spaces_occ_frac
        elsif threshold_calc_method == "normalized_annual_range"
          occ_status = 0 # unoccupied
          if spaces_occ_frac >= annual_normalized_tol
            occ_status = 1
          end
        elsif threshold_calc_method == "normalized_daily_range"
          occ_status = 0 # unoccupied
          if spaces_occ_frac > daily_normalized_tol
            occ_status = 1
          end
        else
          occ_status = 0 # unoccupied
          if spaces_occ_frac > occupied_percentage_threshold
            occ_status = 1
          end
        end

        # Add this data to the daily arrays
        daily_times << time
        daily_os_times << os_time
        daily_values << occ_status
        daily_occs << spaces_occ_frac.round(2)
      end

      # Simplify the daily times to eliminate intermediate points with the same value as the following point
      simple_daily_times = []
      simple_daily_os_times = []
      simple_daily_values = []
      simple_daily_occs = []
      daily_values.each_with_index do |value, j|
        next if value == daily_values[j + 1]
        simple_daily_times << daily_times[j]
        simple_daily_os_times << daily_os_times[j]
        simple_daily_values << daily_values[j]
        simple_daily_occs << daily_occs[j]
      end

      # Store the daily values
      yearly_data << { 'date' => os_date, 'day_of_week' => day_of_week, 'times' => simple_daily_times, 'values' => simple_daily_values, 'daily_os_times' => simple_daily_os_times, 'daily_occs' => simple_daily_occs }
    end

    # Create a TimeSeries from the data
    # time_series = OpenStudio::TimeSeries.new(times, values, 'unitless')

    # Make a schedule ruleset
    if sch_name.nil?
      sch_name = "#{spaces.size} space(s) Occ Sch"
    end
    sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(spaces[0].model)
    sch_ruleset.setName(sch_name.to_s)
    # add properties to schedule
    props = sch_ruleset.additionalProperties
    props.setFeature("max_occ_in_spaces",max_occ_in_spaces)
    props.setFeature("number_of_spaces_included",spaces.size)
    # nothing uses this but can make user be aware if this may be out of sync with current state of occupancy profiles
    props.setFeature("date_parent_object_last_edited",Time.now.getgm.to_s)
    props.setFeature("date_parent_object_created",Time.now.getgm.to_s)

    # Default - All Occupied
    day_sch = sch_ruleset.defaultDaySchedule
    day_sch.setName("#{sch_name} Default")
    day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

    # Winter Design Day - All Occupied
    day_sch = OpenStudio::Model::ScheduleDay.new(spaces[0].model)
    sch_ruleset.setWinterDesignDaySchedule(day_sch)
    day_sch = sch_ruleset.winterDesignDaySchedule
    day_sch.setName("#{sch_name} Winter Design Day")
    day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

    # Summer Design Day - All Occupied
    day_sch = OpenStudio::Model::ScheduleDay.new(spaces[0].model)
    sch_ruleset.setSummerDesignDaySchedule(day_sch)
    day_sch = sch_ruleset.summerDesignDaySchedule
    day_sch.setName("#{sch_name} Summer Design Day")
    day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 1)

    # Create ruleset schedules, attempting to create the minimum number of unique rules
    ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].each do |weekday|
      end_of_prev_rule = yearly_data[0]['date']
      yearly_data.each_with_index do |daily_data, k|
        # Skip unless it is the day of week
        # currently under inspection
        day = daily_data['day_of_week']
        next unless day == weekday
        date = daily_data['date']
        times = daily_data['times']
        values = daily_data['values']
        daily_occs = daily_data['daily_occs']

        # If the next (Monday, Tuesday, etc.) is the same as today, keep going
        # If the next is different, or if we've reached the end of the year, create a new rule
        unless yearly_data[k + 7].nil?
          next_day_times = yearly_data[k + 7]['times']
          next_day_values = yearly_data[k + 7]['values']
          next if times == next_day_times && values == next_day_values
        end

        daily_os_times = daily_data['daily_os_times']
        daily_occs = daily_data['daily_occs']

        # If here, we need to make a rule to cover from the previous rule to today
        OpenStudio.logFree(OpenStudio::Debug, 'openstudio.Standards.Model', "Making a new rule for #{weekday} from #{end_of_prev_rule} to #{date}")
        sch_rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset)
        sch_rule.setName("#{sch_name} #{weekday} Rule")
        day_sch = sch_rule.daySchedule
        day_sch.setName("#{sch_name} #{weekday}")
        daily_os_times.each_with_index do |time, t|
          value = values[t]
          next if value == values[t + 1] # Don't add breaks if same value
          day_sch.addValue(time, value)
        end

        # Set the dates when the rule applies
        sch_rule.setStartDate(end_of_prev_rule)
        # for end dates in last week of year force it to use 12/31. Avoids issues if year or start day of week changes
        start_of_last_week = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 25, year.assumedYear)
        if date >= start_of_last_week
          year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year.assumedYear)
          sch_rule.setEndDate(year_end_date)
        else
          sch_rule.setEndDate(date)
        end

        # Individual Days
        sch_rule.setApplyMonday(true) if weekday == 'Monday'
        sch_rule.setApplyTuesday(true) if weekday == 'Tuesday'
        sch_rule.setApplyWednesday(true) if weekday == 'Wednesday'
        sch_rule.setApplyThursday(true) if weekday == 'Thursday'
        sch_rule.setApplyFriday(true) if weekday == 'Friday'
        sch_rule.setApplySaturday(true) if weekday == 'Saturday'
        sch_rule.setApplySunday(true) if weekday == 'Sunday'

        # Reset the previous rule end date
        end_of_prev_rule = date + OpenStudio::Time.new(0, 24, 0, 0)
      end
    end

    # utilize default profile and common similar days of week for same date range
    # todo - if move to method in Standards.ScheduleRuleset.rb update code to check if default profile is used before replacing it with lowest priority rule.
    # todo - also merging non adjacent priority rules without getting rid of any rules between the two could create unexpected results
    prior_rules = []
    sch_ruleset.scheduleRules.each do |rule|
      if prior_rules.size == 0
        prior_rules << rule
        next
      else
        rules_combined = false
        prior_rules.each do |prior_rule|
          # see if they are similar
          next if rules_combined
          # todo - update to combine adjacent date ranges vs. just matching date ranges
          next if prior_rule.startDate.get != rule.startDate.get
          next if prior_rule.endDate.get != rule.endDate.get
          next if prior_rule.daySchedule.times.to_a != rule.daySchedule.times.to_a
          next if prior_rule.daySchedule.values.to_a != rule.daySchedule.values.to_a

          # combine dates of week
          if rule.applyMonday then prior_rule.setApplyMonday(true) && rules_combined = true end
          if rule.applyTuesday then prior_rule.setApplyTuesday(true) && rules_combined = true end
          if rule.applyWednesday then prior_rule.setApplyWednesday(true) && rules_combined = true end
          if rule.applyThursday then prior_rule.setApplyThursday(true) && rules_combined = true end
          if rule.applyFriday then prior_rule.setApplyFriday(true) && rules_combined = true end
          if rule.applySaturday then prior_rule.setApplySaturday(true) && rules_combined = true end
          if rule.applySunday then prior_rule.setApplySunday(true) && rules_combined = true end
        end
        if rules_combined then rule.remove else prior_rules << rule end
      end
    end
    # replace unused default profile with lowest priority rule
    values = prior_rules.last.daySchedule.values
    times = prior_rules.last.daySchedule.times
    prior_rules.last.remove
    sch_ruleset.defaultDaySchedule.clearValues
    values.size.times do |i|
      sch_ruleset.defaultDaySchedule.addValue(times[i],values[i])
    end

    return sch_ruleset
  end

  # todo - add related related to space_hours_of_operation like set_space_hours_of_operation and shift_and_expand_space_hours_of_operation
  # todo - ideally these could take in a date range, array of dates and or days of week. Hold off until need is a bit more defined.

  # If the model has an hours of operation schedule set in default schedule set for building that looks valid it will
  # report hours of operation. Won't be a single set of values, will be a collection of rules
  # note Building, space, and spaceType can get hours of operation from schedule set, but not buildingStory
  #
  # @author David Goldwasser
  # @param space [Space] takes space
  # @return [Hash] start and end of hours of operation, stat date, end date, bool for each day of the week
  def self.space_hours_of_operation(space)

    standard = Standard.build("90.1-2013")

    default_sch_type = OpenStudio::Model::DefaultScheduleType.new('HoursofOperationSchedule')
    hours_of_operation = space.getDefaultSchedule(default_sch_type)
    if !hours_of_operation.is_initialized
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "Hours of Operation Schedule is not set for #{space.name}.")
      return nil
    end
    hours_of_operation = hours_of_operation.get
    if !hours_of_operation.to_ScheduleRuleset.is_initialized
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "Hours of Operation Schedule #{hours_of_operation.name} is not a ScheduleRuleset.")
      return nil
    end
    hours_of_operation = hours_of_operation.to_ScheduleRuleset.get
    profiles = {}

    # get indices for current schedule
    year_description = hours_of_operation.model.yearDescription.get
    year = year_description.assumedYear
    year_start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('January'), 1, year)
    year_end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new('December'), 31, year)
    indices_vector = hours_of_operation.getActiveRuleIndices(year_start_date, year_end_date)

    # add default profile to hash
    hoo_start = nil
    hoo_end = nil
    unexpected_val = false
    times = hours_of_operation.defaultDaySchedule.times
    values = hours_of_operation.defaultDaySchedule.values
    times.each_with_index do |time,i|
      if values[i] == 0 && hoo_start.nil?
        hoo_start = time.totalHours
      elsif values[i] == 1 && hoo_end.nil?
        hoo_end = time.totalHours
      elsif values[i] != 1 && values[i] != 0
        unexpected_val = true
      end
    end

    # address schedule that is always on or always off (start and end can not both be nil unless unexpected value was found)
    if !hoo_start.nil? && hoo_end.nil?
      hoo_end = hoo_start
    elsif !hoo_end.nil? && hoo_start.nil?
      hoo_start = hoo_end
    end

    # some validation
    if times.size > 3 || unexpected_val || hoo_start.nil? || hoo_end.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "#{hours_of_operation.name} does not look like a valid hours of operation schedule for parametric schedule generation.")
      return nil
    end

    # hours of operation start and finish
    rule_hash = {}
    rule_hash[:hoo_start] = hoo_start
    rule_hash[:hoo_end] = hoo_end
    hoo_hours = nil
    if hoo_start == hoo_end
      if values .uniq == [1]
        hoo_hours = 24
      else
        hoo_hours = 0
      end
    elsif hoo_end > hoo_start
      hoo_hours = hoo_end - hoo_start
    elsif hoo_start > hoo_end
      hoo_hours = hoo_end + 24 - hoo_start
    end
    rule_hash[:hoo_hours] = hoo_hours
    days_used = []
    indices_vector.each_with_index do |profile_index,i|
      if profile_index == -1 then days_used << i+1 end
    end
    rule_hash[:days_used] = days_used
    profiles[-1] = rule_hash

    hours_of_operation.scheduleRules.reverse.each do |rule|
      # may not need date and days of week, will likely refer to specific date and get rule when applying parametricformula
      rule_hash = {}

      hoo_start = nil
      hoo_end = nil
      unexpected_val = false
      times = rule.daySchedule.times
      values = rule.daySchedule.values
      times.each_with_index do |time,i|
        if values[i] == 0 && hoo_start.nil?
          hoo_start = time.totalHours
        elsif values[i] == 1  && hoo_end.nil?
          hoo_end = time.totalHours
        elsif values[i] != 1 && values[i] != 0
          unexpected_val = true
        end
      end

      # address schedule that is always on or always off (start and end can not both be nil unless unexpected value was found)
      if !hoo_start.nil? && hoo_end.nil?
        hoo_end = hoo_start
      elsif !hoo_end.nil? && hoo_start.nil?
      hoo_start = hoo_end
      end

      # some validation
      if times.size > 3 || unexpected_val || hoo_start.nil? || hoo_end.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'openstudio.model.Space', "#{hours_of_operation.name} does not look like a valid hours of operation schedule for parametric schedule generation.")
        return nil
      end

      # hours of operation start and finish
      rule_hash[:hoo_start] = hoo_start
      rule_hash[:hoo_end] = hoo_end
      hoo_hours = nil
      if hoo_start == hoo_end
        if values .uniq == [1]
          hoo_hours = 24
        else
          hoo_hours = 0
        end
      elsif hoo_end > hoo_start
        hoo_hours = hoo_end - hoo_start
      elsif hoo_start > hoo_end
        hoo_hours = hoo_end + 24 - hoo_start
      end
      rule_hash[:hoo_hours] = hoo_hours
      days_used = []
      indices_vector.each_with_index do |profile_index,i|
        if profile_index == rule.ruleIndex then days_used << i+1 end
      end
      rule_hash[:days_used] = days_used

=begin
      # todo - delete rule details below unless end up needing to use them
      if rule.startDate.is_initialized
        date = rule.startDate.get
        rule_hash[:start_date] = "#{date.monthOfYear.value}/#{date.dayOfMonth}"
      else
        rule_hash[:start_date] = nil
      end
      if rule.endDate.is_initialized
        date = rule.endDate.get
        rule_hash[:end_date] = "#{date.monthOfYear.value}/#{date.dayOfMonth}"
      else
        rule_hash[:end_date] = nil
      end
      rule_hash[:mon] = rule.applyMonday
      rule_hash[:tue] = rule.applyTuesday
      rule_hash[:wed] = rule.applyWednesday
      rule_hash[:thu] = rule.applyThursday
      rule_hash[:fri] = rule.applyFriday
      rule_hash[:sat] = rule.applySaturday
      rule_hash[:sun] = rule.applySunday
=end

      # update hash
      profiles[rule.ruleIndex] = rule_hash

    end

    return profiles
  end

end
