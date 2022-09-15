#!/bin/bash
#
# Title: "Atlas of historical county boundaries" Processing Script
# By: Mark A. Connelly
# Year: 2022
# License: Creative Commons Zero (CC0)
# Operating System: Ubuntu 20.04
#
# Note: if the CURL operation fails, navigate to https://www.loc.gov/item/2018487899/ and download the "US dataset" (1.0 GB).
#
# Before starting the script, do the following:
#   1. Set POSTGRESQL_PASSWORD_VALUE appropriately in the script.
#   2. Ensure that NewberryLoc.sql is in the same directory as this script, and that the script is to be run in the same directory.
#
# Keep track of started time
now=$(date +"%T")
echo "Started: $now"
# Download ZIP file
curl https://tile.loc.gov/storage-services/master/gdc/gdcdatasets/2018487899_us/2018487899_us.zip --output master-gdc-gdcdatasets-2018487899_us-2018487899_us.zip
# Retrieve appropriate shapefiles from ZIP file
unzip -j master-gdc-gdcdatasets-2018487899_us-2018487899_us.zip 2018487899_us/2018487899_US_Historical_Counties_1629-2000.zip 2018487899_us/2018487899_US_Historical_States_and_Territories_1783-2000.zip
unzip -j 2018487899_US_Historical_Counties_1629-2000.zip US_Historical_Counties_1629-2000/US_AtlasHCB_Counties.zip
rm 2018487899_US_Historical_Counties_1629-2000.zip
unzip -j US_AtlasHCB_Counties.zip US_AtlasHCB_Counties/US_HistCounties_Shapefile/*
rm US_AtlasHCB_Counties.zip
unzip -j 2018487899_US_Historical_States_and_Territories_1783-2000.zip US_Historical_States_and_Territories_1783-2000/US_AtlasHCB_StateTerr.zip
rm 2018487899_US_Historical_States_and_Territories_1783-2000.zip
unzip -j US_AtlasHCB_StateTerr.zip US_AtlasHCB_StateTerr/US_HistStateTerr_Shapefile/*
rm US_AtlasHCB_StateTerr.zip
# Set POSTGRESQL_PASSWORD_VALUE appropriately before running
export PGPASSWORD="POSTGRESQL_PASSWORD_VALUE"
# Create database and ensure it is PostGIS-enabled
psql --host=127.0.0.1 --port=5432 --username=postgres --no-password --command="CREATE DATABASE newberrytopology;" postgres
psql --host=127.0.0.1 --port=5432 --username=postgres --no-password --command="CREATE EXTENSION postgis;" newberrytopology
# Upload shapefiles and delete files
shp2pgsql -I -s 4326 US_HistCounties.shp us_histcounties | psql --host=127.0.0.1 --port=5432 --username=postgres --no-password newberrytopology
shp2pgsql -I -s 4326 US_HistStateTerr.shp us_histstateterr | psql --host=127.0.0.1 --port=5432 --username=postgres --no-password newberrytopology
rm US_Hist*
# Run processing SQL
psql --host=127.0.0.1 --port=5432 --username=postgres --no-password --file=NewberryLoc.sql newberrytopology
# Export processed data
psql --host=127.0.0.1 --port=5432 --username=postgres --no-password --command="COPY (SELECT us_histcounties.id_num, name, id, state_terr, fips, version, start_date, end_date, change, citation, start_n, end_n, area_sqmi, cnty_type, full_name, cross_ref, name_start FROM us_histcounties ORDER BY 1) TO stdout WITH CSV HEADER;" newberrytopology > output_counties_metadata.csv;
psql --host=127.0.0.1 --port=5432 --username=postgres --no-password --command="COPY (SELECT id_num, edge_id, edge_type FROM topologydata.us_histcounties_topology_edge ORDER BY gid) TO stdout WITH CSV HEADER;" newberrytopology > output_counties_ways.csv;
psql --host=127.0.0.1 --port=5432 --username=postgres --no-password --command="COPY (SELECT id_num, name, id, version, start_date, end_date, change, citation, start_n, end_n, area_sqmi, terr_type, full_name, abbr_name, name_start FROM us_histstateterr ORDER BY 1) TO stdout WITH CSV HEADER;" newberrytopology > output_states_metadata.csv;
psql --host=127.0.0.1 --port=5432 --username=postgres --no-password --command="COPY (SELECT id_num, edge_id, edge_type FROM topologydata.us_histstateterr_topology_edge ORDER BY gid) TO stdout WITH CSV HEADER;" newberrytopology > output_states_ways.csv;
pgsql2shp -f output_ways -h 127.0.0.1 -p 5432 -u postgres newberrytopology "SELECT edge_id, geom FROM topologydata.edge_data ORDER BY 1"
# ZIP output data
zip OHM_Newberry_Output.zip output*
rm output*
# Keep track of completed time
now=$(date +"%T")
echo "Completed: $now"
