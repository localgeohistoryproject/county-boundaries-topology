# Atlas of Historical County Boundaries: Conversion to Topology

[![DOI](https://zenodo.org/badge/536871432.svg)](https://zenodo.org/badge/latestdoi/536871432)

## Summary

The Atlas of Historical County Boundaries is a resource created by [The Newberry Library](https://www.newberry.org/), Chicago, Illinois, to document changes in county and county-equivalent boundaries in the United States of America over time. In 2019, The Newberry Library donated the project shapefiles to the Library of Congress and released them under a [Creative Commons CC0 "No Rights Reserved" License](https://creativecommons.org/share-your-work/public-domain/cc0/).

Each multipolygon feature in the project shapefile data represents a particular government unit (or non-county or disputed area) for a particular time period. In order to avoid duplication of shared boundaries, the scripts in this repository convert these features into least common geometries,[^1] which, once further converted to a PostGIS topology and exported as edges (or "ways"), can be imported into other projects with topological data models, like OpenHistoricalMap.

[^1]: Martina De Moor and Torsten Wiedemann, "Reconstructing Territorial Units and Hierarchies: A Belgian Example," *History and Computing* 13, no. 1 (March 2001): 71-98, https://doi.org/10.3366/hac.2001.13.1.71.

## Scripts

There are two files in the script folder. The shell script, NewberryLoc.sh, which was created for Ubuntu 20.04:

  * Downloads the ZIP files from the Library of Congress website.
  * Retrieves the appropriate shapefiles from each ZIP file.
  * Creates a new PostGIS-enabled database in PostgreSQL called newberrytopology.
  * Imports the shapefiles using shp2pgsql, and then deletes the unzipped shapefiles.
  * Runs the processing SQL script, which is detailed below.
  * Exports the processed data and places it in one ZIP file (whose contents have been placed in the output folder).

The processing SQL script, NewberryLoc.sql, which was created for PostgreSQL 14.4:

  * Creates a base polygon layer from the imported multipolygons consisting of the county boundaries as of the end of 2000 and additional areas covered by the atlas outside of the United States of America.
  * Splits the base polygon layer using non-matching segments from all of the historic county and state multipolygons, creating least common geometries.
  * Creates a PostGIS topology from the least common geometries.
  * Determines which edges in the PostGIS topology correspond with each of the imported multipolygons, with an attempt to separate out outer rings from inner rings.

## Output

The script output consists of four CSV files, along with a shapefile. The CSVs ending in _metadata.csv contain the original field data for each of the multipolygon features in the downloaded shapefiles, including the *id_num* primary key. The output_ways shapefile (.cpg, .dbf, .prj, .shp, .shx) includes the edges (or "ways") derived from the PostGIS topology created from the least common geometries, with the sole metadata field being a primary key, *edge_id*. The CSVs ending in _ways.csv link *id_num* values in the _metadata.csv CSVs with each *edge_id* in the shapefiles, along with the predicted edge type, allowing for the creation of faces (or "relations") in other projects with topological data models, like OpenHistoricalMap.

## Source Data

https://www.loc.gov/item/2018487899/

## More Information about the Atlas of Historical County Boundaries

https://digital.newberry.org/ahcb/

## Credits

Thanks are given to The Newberry Library, with which the owner of this repository is not affiliated, for creating the Atlas of Historical County Boundaries and sharing its data with the public.
