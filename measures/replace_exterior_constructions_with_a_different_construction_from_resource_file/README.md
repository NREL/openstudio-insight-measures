

###### (Automatically generated documentation)

# Replace Exterior Constructions with a Different Construction from Resource File

## Description
Replace exterior wall, roof, or window constructions, with an existing construction from a construction imported from a resource file.

## Modeler Description
This will take an argument for a target construction to import from a resource GbXML file. How that construction is applied in the model or tagged in the resource file will determine which surface types the construction is applied to.

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Target Construction from Library to use for Exterior Surface Replacement

**Name:** new_construction,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false


**Choice Display Names** ["R-13+R13 metal frame + ins. panel (SIP) wall, 14\\\", 4 1/2 in (114 mm)", "Membrane, sheathing, R-15 insulation, 4 1/4 in light concrete", "Low-E double glazing (1/4 in + 1/4 in) U-1.98 SHGC-0.56"]



### Cardinal Direction.
Constructions will be applied to the specified facade or facades.
**Name:** facade,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false


**Choice Display Names** ["North", "East", "South", "West", "All"]






