

###### (Automatically generated documentation)

# Replace Exterior Constructions with a Different Construction from Resource File

## Description
Replace exterior wall, roof, or window constructions, with construction from a resource file.

## Modeler Description
This will only have an argument for target construction. How that construction is tagged in the resource file will determine which surface types the construction is applied to.

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Target Construction for Exterior Surface Replacement

**Name:** new_construction,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false


**Choice Display Names** ["Roof 10.25-inch SIP", "Roof R10", "Roof R15", "Roof R19", "Roof R38", "Roof R60", "Roof Uninsulated", "Wall 12.25-inch SIP", "Wall 14-inch ICF", "Wall R13 Metal", "Wall R13 Wood", "Wall R13+R10 Metal", "Wall R2 CMU", "Wall R38 Wood", "Wall Uninsulated", "Window Dbl LoE", "Window Sgl Clr", "Window Trp Clr", "Window Trp LoE"]



### Cardinal Direction.
Constructions will be applied to the specified facade or facades.
**Name:** facade,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false


**Choice Display Names** ["North", "East", "South", "West", "All"]






