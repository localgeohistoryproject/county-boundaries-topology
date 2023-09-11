#!/bin/bash
#
# Title: "Atlas of Historical County Boundaries" Processing Script
# By: Mark A. Connelly
# Year: 2022-2023
# License: Creative Commons Zero (CC0)
# Operating System: Ubuntu 20.04 or 22.04
#
# Note: if the CURL operation fails, navigate to https://www.loc.gov/item/2018487899/ and download the "US dataset" (1.0 GB).
#
# Keep track of started time
now=$(date +"%T")
echo "Started: $now"
# Check if necessary programs installed
which curl &> /dev/null
if [ $? -gt 0 ]; then echo "ERROR: curl must be installed to run this script."; exit 1; fi;
which pgsql2shp &> /dev/null
if [ $? -gt 0 ]; then echo "ERROR: pgsql2shp must be installed to run this script."; exit 1; fi;
which psql &> /dev/null
if [ $? -gt 0 ]; then echo "ERROR: psql must be installed to run this script."; exit 1; fi;
which shp2pgsql &> /dev/null
if [ $? -gt 0 ]; then echo "ERROR: shp2pgsql must be installed to run this script."; exit 1; fi;
which unzip &> /dev/null
if [ $? -gt 0 ]; then echo "ERROR: unzip must be installed to run this script."; exit 1; fi;
if [ ! -f "../.env" ]; then echo "ERROR: Environmental variable file (.env) must be created to run this script."; exit 1; fi;
# Set environmental variables
source ../.env
export PGPASSWORD=$POSTGRES_PASSWORD
# Download ZIP file if required
if [ "" == "$LOC_LOCATION" ]; then
  LOC_LOCATION=locfile
  curl https://tile.loc.gov/storage-services/master/gdc/gdcdatasets/2018487899_us/2018487899_us.zip --output "$LOC_LOCATION"
elif [ ! -f "$LOC_LOCATION" ]; then
  echo "ERROR: Missing dataset ZIP.";
  exit 1;
fi;
# Retrieve appropriate shapefiles from ZIP file
unzip -j "$LOC_LOCATION" 2018487899_us/2018487899_US_Historical_Counties_1629-2000.zip 2018487899_us/2018487899_US_Historical_States_and_Territories_1783-2000.zip
unzip -j 2018487899_US_Historical_Counties_1629-2000.zip US_Historical_Counties_1629-2000/US_AtlasHCB_Counties.zip
rm 2018487899_US_Historical_Counties_1629-2000.zip
unzip -j US_AtlasHCB_Counties.zip US_AtlasHCB_Counties/US_HistCounties_Shapefile/*
rm US_AtlasHCB_Counties.zip
unzip -j 2018487899_US_Historical_States_and_Territories_1783-2000.zip US_Historical_States_and_Territories_1783-2000/US_AtlasHCB_StateTerr.zip
rm 2018487899_US_Historical_States_and_Territories_1783-2000.zip
unzip -j US_AtlasHCB_StateTerr.zip US_AtlasHCB_StateTerr/US_HistStateTerr_Shapefile/*
rm US_AtlasHCB_StateTerr.zip
# Create database and ensure it is PostGIS-enabled
psql --host=$POSTGRES_HOST --port=$POSTGRES_PORT --username=$POSTGRES_USER --no-password --command="CREATE DATABASE $POSTGRES_DB;" $POSTGRES_DEFAULT_DB
psql --host=$POSTGRES_HOST --port=$POSTGRES_PORT --username=$POSTGRES_USER --no-password --command="CREATE EXTENSION postgis;" $POSTGRES_DB
# Upload shapefiles and delete files
shp2pgsql -I -s 4326 US_HistCounties.shp us_histcounties | psql --host=$POSTGRES_HOST --port=$POSTGRES_PORT --username=$POSTGRES_USER --no-password $POSTGRES_DB
shp2pgsql -I -s 4326 US_HistStateTerr.shp us_histstateterr | psql --host=$POSTGRES_HOST --port=$POSTGRES_PORT --username=$POSTGRES_USER --no-password $POSTGRES_DB
rm US_Hist*
# Run processing SQL
psql --host=$POSTGRES_HOST --port=$POSTGRES_PORT --username=$POSTGRES_USER --no-password --file=NewberryLoc.sql $POSTGRES_DB
# Export processed data
psql --host=$POSTGRES_HOST --port=$POSTGRES_PORT --username=$POSTGRES_USER --no-password --command="COPY (SELECT us_histcounties.id_num, name, id, state_terr, fips, version, start_date, end_date, change, citation, start_n, end_n, area_sqmi, cnty_type, full_name, cross_ref, name_start FROM us_histcounties ORDER BY 1) TO stdout WITH CSV HEADER;" $POSTGRES_DB > ../output/output_counties_metadata.csv;
psql --host=$POSTGRES_HOST --port=$POSTGRES_PORT --username=$POSTGRES_USER --no-password --command="COPY (SELECT id_num, edge_id, edge_type FROM topologydata.us_histcounties_topology_edge ORDER BY gid) TO stdout WITH CSV HEADER;" $POSTGRES_DB > ../output/output_counties_ways.csv;
psql --host=$POSTGRES_HOST --port=$POSTGRES_PORT --username=$POSTGRES_USER --no-password --command="COPY (SELECT id_num, name, id, version, start_date, end_date, change, citation, start_n, end_n, area_sqmi, terr_type, full_name, abbr_name, name_start FROM us_histstateterr ORDER BY 1) TO stdout WITH CSV HEADER;" $POSTGRES_DB > ../output/output_states_metadata.csv;
psql --host=$POSTGRES_HOST --port=$POSTGRES_PORT --username=$POSTGRES_USER --no-password --command="COPY (SELECT id_num, edge_id, edge_type FROM topologydata.us_histstateterr_topology_edge ORDER BY gid) TO stdout WITH CSV HEADER;" $POSTGRES_DB > ../output/output_states_ways.csv;
pgsql2shp -f ../output/output_ways -h $POSTGRES_HOST -p $POSTGRES_PORT -u $POSTGRES_USER $POSTGRES_DB "SELECT edge_fips.fips_edge_id AS edge_id, geom FROM topologydata.edge_data JOIN topologydata.edge_fips ON edge_data.edge_id = edge_fips.edge_id ORDER BY 1"
# Keep track of completed time
now=$(date +"%T")
echo "Completed: $now"
