# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class ReduceInsightOutput < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Reduce Insight Output'
  end

  # human readable description
  def description
    return 'Reduces the output SQLFile file size to the minimum required for Insight360. Optionally suppresses other output files.'
  end

  # human readable description of modeling approach
  def modeler_description
    return ''
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    suppress_files = OpenStudio::Measure::OSArgument.makeBoolArgument('suppress_files', true)
    suppress_files.setDisplayName('Suppress Output Files')
    suppress_files.setDescription('Suppresses all output files except eplusout.sql from being generated for the run.')
    suppress_files.setDefaultValue(true)
    args << suppress_files

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)  # Do **NOT** remove this line

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    suppress_files = runner.getBoolArgumentValue('suppress_files', user_arguments)

    # disable sizing period simulation
    model.getSimulationControl.setRunSimulationforSizingPeriods(false)

    # remove all output variables and output meters from the model
    # this data is written to SQLFile if included
    model.getOutputVariables.each(&:remove)
    model.getOutputMeters.each(&:remove)
    if model.outputConstructions.is_initialized
      model.getOutputConstructions.setReportConstructions(false)
      model.getOutputConstructions.setReportMaterials(false)
    end
    if model.outputEnergyManagementSystem.is_initialized
      model.getOutputEnergyManagementSystem.setActuatorAvailabilityDictionaryReporting('None')
      model.getOutputEnergyManagementSystem.setInternalVariableAvailabilityDictionaryReporting('None')
      model.getOutputEnergyManagementSystem.setEMSRuntimeLanguageDebugOutputLevel('None')
    end
    if model.outputSchedules.is_initialized
      model.getOutputSchedules.remove
    end

    # test change workflowJSON settings
    fto = OpenStudio::ForwardTranslatorOptions.new
    # no HTML output will be created
    fto.setExcludeHTMLOutputReport(true)
    fto.setExcludeLCCObjects(true)
    ro = OpenStudio::RunOptions.new
    ro.setForwardTranslatorOptions(fto)
    # this skips the default output:tables and output:meters
    ro.setSkipEnergyPlusPreprocess(true)
    ro.setSkipZipResults(true)
    workflow = model.workflowJSON
    workflow.setRunOptions(ro)


    # specify Output:Table:SummaryReports
    otsr = model.getOutputTableSummaryReports
    # removing all, still leaves monthly energy and demand tables by end-use. 
    otsr.removeAllSummaryReports
    # otsr.addSummaryReport('AnnualBuildingUtilityPerformanceSummary')
    # otsr.addSummaryReport('EnergyMeters')

    # this will remove tabulardata, tabulardatawithstrings tables
    # model.getOutputSQLite.setOptionType('Simple')

    if suppress_files
      ocf = model.getOutputControlFiles
      ocf.setOutputCSV(false)
      ocf.setOutputMTR(false)
      ocf.setOutputESO(false)
      ocf.setOutputEIO(false)
      ocf.setOutputTabular(false)
      ocf.setOutputJSON(false)
      ocf.setOutputAUDIT(false)
      ocf.setOutputZoneSizing(false)
      ocf.setOutputSystemSizing(false)
      ocf.setOutputDXF(false)
      ocf.setOutputBND(false)
      ocf.setOutputRDD(false)
      ocf.setOutputMDD(false)
      ocf.setOutputMTD(false)
      ocf.setOutputSHD(false)
      ocf.setOutputDFS(false)
      ocf.setOutputGLHE(false)
      ocf.setOutputDelightIn(false)
      ocf.setOutputDelightELdmp(false)
      ocf.setOutputDelightDFdmp(false)
      ocf.setOutputEDD(false)
      ocf.setOutputDBG(false)
      ocf.setOutputPerfLog(false)
      ocf.setOutputSLN(false)
      ocf.setOutputSCI(false)
      ocf.setOutputWRL(false)
      ocf.setOutputScreen(false)
      ocf.setOutputExtShd(false)
      ocf.setOutputTarcog(false)
      runner.registerInfo('Suppressed all output files except SQL')
    end

    # report final condition of model
    runner.registerFinalCondition("Model output has been reduced.")

    return true
  end
end

# register the measure to be used by the application
ReduceInsightOutput.new.registerWithApplication
