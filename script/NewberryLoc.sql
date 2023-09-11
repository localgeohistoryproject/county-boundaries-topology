--
-- Title: "Atlas of Historical County Boundaries" Processing SQL
-- By: Mark A. Connelly
-- Year: 2022-2023
-- License: Creative Commons Zero (CC0)
-- Operating System: Ubuntu 20.04 or 22.04
-- PostgreSQL Version: 14 or 15
--

-- Trim field to remove trailing line break

UPDATE us_histcounties
SET full_name = trim(full_name);

-- Break multipolygons into polygons

CREATE TABLE IF NOT EXISTS us_histcounties_polygon
(
    gid serial NOT NULL,
    id_num integer,
    name character varying(20) COLLATE pg_catalog."default",
    id character varying(50) COLLATE pg_catalog."default",
    state_terr character varying(50) COLLATE pg_catalog."default",
    fips character varying(5) COLLATE pg_catalog."default",
    version smallint,
    start_date date,
    end_date date,
    change character varying(254) COLLATE pg_catalog."default",
    citation character varying(254) COLLATE pg_catalog."default",
    start_n integer,
    end_n integer,
    area_sqmi numeric,
    cnty_type character varying(25) COLLATE pg_catalog."default",
    full_name character varying(50) COLLATE pg_catalog."default",
    cross_ref character varying(80) COLLATE pg_catalog."default",
    name_start character varying(40) COLLATE pg_catalog."default",
    geom geometry(Polygon,4326),
    currentisexact boolean NOT NULL DEFAULT FALSE,
    splitid integer,
    CONSTRAINT us_histcounties_polygon_pkey PRIMARY KEY (gid)
);

CREATE INDEX IF NOT EXISTS us_histcounties_polygon_geom_idx
    ON us_histcounties_polygon USING gist
    (geom);

CREATE INDEX IF NOT EXISTS us_histcounties_polygon_splitid_idx
    ON us_histcounties_polygon USING btree
    (splitid ASC NULLS LAST);
    
INSERT INTO us_histcounties_polygon (id_num, name, id, state_terr, fips, version, start_date, end_date, change, citation, start_n, end_n, area_sqmi, cnty_type, full_name, cross_ref, name_start, geom)
SELECT id_num, name, id, state_terr, fips, version, start_date, end_date, change, citation, start_n, end_n, area_sqmi, cnty_type, full_name, cross_ref, name_start,
  (ST_Dump(ST_Multi(geom))).geom AS geom
FROM us_histcounties
ORDER BY 1;

CREATE TABLE IF NOT EXISTS us_histstateterr_polygon
(
    gid serial NOT NULL,
    id_num integer,
    name character varying(20) COLLATE pg_catalog."default",
    id character varying(50) COLLATE pg_catalog."default",
    version smallint,
    start_date date,
    end_date date,
    change character varying(254) COLLATE pg_catalog."default",
    citation character varying(254) COLLATE pg_catalog."default",
    start_n integer,
    end_n integer,
    area_sqmi numeric,
    terr_type character varying(25) COLLATE pg_catalog."default",
    full_name character varying(50) COLLATE pg_catalog."default",
    abbr_name character varying(15) COLLATE pg_catalog."default",
    name_start character varying(40) COLLATE pg_catalog."default",
    geom geometry(Polygon,4326),
    currentisexact boolean NOT NULL DEFAULT FALSE,
    splitid integer,
    CONSTRAINT us_histstateterr_polygon_pkey PRIMARY KEY (gid)
);

CREATE INDEX IF NOT EXISTS us_histstateterr_polygon_geom_idx
    ON us_histstateterr_polygon USING gist
    (geom);

CREATE INDEX IF NOT EXISTS us_histstateterr_polygon_splitid_idx
    ON us_histstateterr_polygon USING btree
    (splitid ASC NULLS LAST);
    
INSERT INTO us_histstateterr_polygon (id_num, name, id, version, start_date, end_date, change, citation, start_n, end_n, area_sqmi, terr_type, full_name, abbr_name, name_start, geom)
SELECT id_num, name, id, version, start_date, end_date, change, citation, start_n, end_n, area_sqmi, terr_type, full_name, abbr_name, name_start,
  (ST_Dump(ST_Multi(geom))).geom AS geom
FROM us_histstateterr
ORDER BY 1;

-- Get current county polygons

CREATE TABLE IF NOT EXISTS us_current
(
    gid serial NOT NULL,
    name character varying(20) COLLATE pg_catalog."default",
    id character varying(50) COLLATE pg_catalog."default",
    state_terr character varying(50) COLLATE pg_catalog."default",
    fips character varying(5) COLLATE pg_catalog."default",
    geom geometry(Polygon,4326),
    CONSTRAINT us_current_pkey PRIMARY KEY (gid)
);

CREATE INDEX IF NOT EXISTS us_current_geom_idx
    ON us_current USING gist
    (geom);

INSERT INTO us_current (name, id, state_terr, fips, geom)
SELECT name, id, state_terr, fips, geom
FROM us_histcounties_polygon
  WHERE us_histcounties_polygon.end_n = 20001231
ORDER BY 1;

-- Determine which historic polygons are exact matches for current county polygons

UPDATE us_histcounties_polygon
SET currentisexact = TRUE
FROM us_current
WHERE NOT us_histcounties_polygon.currentisexact
AND ST_Equals(us_current.geom, us_histcounties_polygon.geom);

UPDATE us_histstateterr_polygon
SET currentisexact = TRUE
FROM us_current
WHERE NOT us_histstateterr_polygon.currentisexact
AND ST_Equals(us_current.geom, us_histstateterr_polygon.geom);

-- Find difference between current counties and historic counties to find areas outside of United States

CREATE MATERIALIZED VIEW wholecurrent AS
 SELECT ST_Union(geom) AS geom
   FROM us_current;

CREATE MATERIALIZED VIEW wholewhole AS
 SELECT ST_Union(geom) AS geom
   FROM us_histcounties_polygon
  WHERE NOT us_histcounties_polygon.currentisexact;

CREATE MATERIALIZED VIEW currentexternal AS
 SELECT (ST_Dump(ST_Multi(ST_Difference(wholewhole.geom, wholecurrent.geom)))).geom AS geom
   FROM wholewhole, wholecurrent;

-- Fold county differences back into current counties

INSERT INTO us_current (geom)
  SELECT geom
  FROM currentexternal;

DROP MATERIALIZED VIEW currentexternal;
DROP MATERIALIZED VIEW wholewhole;
DROP MATERIALIZED VIEW wholecurrent;

-- Rerun differences queries

UPDATE us_histcounties_polygon
SET currentisexact = TRUE
FROM us_current
WHERE NOT us_histcounties_polygon.currentisexact
AND ST_Equals(us_current.geom, us_histcounties_polygon.geom);

UPDATE us_histstateterr_polygon
SET currentisexact = TRUE
FROM us_current
WHERE NOT us_histstateterr_polygon.currentisexact
AND ST_Equals(us_current.geom, us_histstateterr_polygon.geom);

-- Find difference between current counties (with areas from county layer outside of country) and historic states to find additional areas outside of United States, to serve as base layer for splitting

CREATE MATERIALIZED VIEW wholecurrent AS
 SELECT ST_Union(geom) AS geom
   FROM us_current;

CREATE MATERIALIZED VIEW wholewhole AS
 SELECT ST_Union(geom) AS geom
   FROM us_histstateterr_polygon
  WHERE NOT us_histstateterr_polygon.currentisexact;

CREATE MATERIALIZED VIEW currentexternal AS
 SELECT (ST_Dump(ST_Multi(ST_Difference(wholewhole.geom, wholecurrent.geom)))).geom AS geom
   FROM wholewhole, wholecurrent;

-- Fold state differences back into current counties

INSERT INTO us_current (geom)
  SELECT geom
  FROM currentexternal;
  
DROP MATERIALIZED VIEW currentexternal;
DROP MATERIALIZED VIEW wholewhole;
DROP MATERIALIZED VIEW wholecurrent;

-- Rerun differences queries

UPDATE us_histcounties_polygon
SET currentisexact = TRUE
FROM us_current
WHERE NOT us_histcounties_polygon.currentisexact
AND ST_Equals(us_current.geom, us_histcounties_polygon.geom);

UPDATE us_histstateterr_polygon
SET currentisexact = TRUE
FROM us_current
WHERE NOT us_histstateterr_polygon.currentisexact
AND ST_Equals(us_current.geom, us_histstateterr_polygon.geom);

-- Break historic polygons that are not exact matches into linestrings

CREATE TABLE IF NOT EXISTS us_linestring
(
    gid serial NOT NULL,
    geom geometry(LineString,4326),
    currentisexact boolean NOT NULL DEFAULT FALSE,
    CONSTRAINT us_linestring_pkey PRIMARY KEY (gid)
);

CREATE INDEX IF NOT EXISTS us_linestring_geom_idx
    ON us_linestring USING gist
    (geom);

INSERT INTO us_linestring (geom)
SELECT DISTINCT (ST_Dump(ST_Multi(ST_Boundary(geom)))).geom AS geom
FROM us_histcounties_polygon
WHERE NOT currentisexact
UNION DISTINCT
SELECT DISTINCT (ST_Dump(ST_Multi(ST_Boundary(geom)))).geom AS geom
FROM us_histstateterr_polygon
WHERE NOT currentisexact;

-- Break current polygons into linestrings

CREATE MATERIALIZED VIEW us_current_linestring AS
SELECT DISTINCT (ST_Dump(ST_Multi(ST_Boundary(geom)))).geom AS geom
FROM us_current;

CREATE INDEX IF NOT EXISTS us_current_linestring_geom_idx
    ON us_current_linestring USING gist
    (geom);

-- Delete historic lines that are exact matches for current lines

UPDATE us_linestring
SET currentisexact = TRUE
FROM us_current_linestring
WHERE NOT us_linestring.currentisexact
AND ST_Equals(us_linestring.geom, us_current_linestring.geom);

DELETE FROM us_linestring
WHERE currentisexact;

-- Break linestrings into segments

CREATE TABLE IF NOT EXISTS us_segment
(
    gid serial NOT NULL,
    geom geometry(LineString,4326),
    currentisexact boolean NOT NULL DEFAULT FALSE,
    CONSTRAINT us_segment_pkey PRIMARY KEY (gid)
);

CREATE INDEX IF NOT EXISTS us_segment_geom_idx
    ON us_segment USING gist
    (geom);

INSERT INTO us_segment (geom) 
SELECT DISTINCT
(ST_DumpSegments(geom)).geom AS geom
FROM us_linestring;

CREATE MATERIALIZED VIEW us_current_segment AS
SELECT DISTINCT
(ST_DumpSegments(geom)).geom AS geom
FROM us_current_linestring;

CREATE INDEX IF NOT EXISTS us_current_segment_geom_idx
    ON us_current_segment USING gist
    (geom);

-- Delete historic segments that are exact matches for current segments

UPDATE us_segment
SET currentisexact = TRUE
FROM us_current_segment
WHERE NOT us_segment.currentisexact
AND ST_Equals(us_segment.geom, us_current_segment.geom);

DELETE FROM us_segment
WHERE currentisexact;

DROP MATERIALIZED VIEW us_current_segment;
DROP MATERIALIZED VIEW us_current_linestring;
DROP TABLE us_linestring;

-- Split current shapes as necessary to create least common geometries

CREATE TABLE IF NOT EXISTS us_split
(
    gid serial NOT NULL,
    name character varying(20) COLLATE pg_catalog."default",
    id character varying(50) COLLATE pg_catalog."default",
    state_terr character varying(50) COLLATE pg_catalog."default",
    fips character varying(5) COLLATE pg_catalog."default",
    geom geometry(Polygon,4326),
    county_id_nums integer[],
    state_id_nums integer[],
    CONSTRAINT us_split_pkey PRIMARY KEY (gid)
);

CREATE INDEX IF NOT EXISTS us_split_geom_idx
    ON us_split USING gist
    (geom);

WITH intersectlines AS (
  SELECT us_current.gid,
    ST_Union(us_segment.geom) AS geom
  FROM us_segment
  JOIN us_current
    ON ST_Intersects(us_segment.geom, us_current.geom)
  GROUP BY 1
)
INSERT INTO us_split (name, id, state_terr, fips, geom)
SELECT name, id, state_terr, fips, geom
FROM us_current
WHERE gid NOT IN (SELECT gid FROM intersectlines)
UNION DISTINCT
SELECT DISTINCT
name, id, state_terr, fips,
(ST_Dump(ST_Multi(ST_Split(us_current.geom, intersectlines.geom)))).geom AS geom
FROM us_current
JOIN intersectlines
  ON us_current.gid = intersectlines.gid
ORDER BY 1;

DROP TABLE us_segment;
DROP TABLE us_current;

-- Match split polygons with original imported table ids

UPDATE us_histcounties_polygon
SET splitid = us_split.gid
FROM us_split
WHERE ST_Equals(us_histcounties_polygon.geom, us_split.geom);

WITH idnumrows AS (
    SELECT DISTINCT us_split.gid,
      id_num
    FROM us_split
    JOIN us_histcounties_polygon
      ON us_split.gid = us_histcounties_polygon.splitid
    UNION DISTINCT
    SELECT DISTINCT
      us_split.gid,
      id_num
    FROM us_split
    JOIN us_histcounties_polygon
      ON splitid IS NULL
      AND ST_Contains(us_histcounties_polygon.geom, us_split.geom)
), idnumgroups AS (
    SELECT DISTINCT
      gid,
      array_agg(id_num ORDER BY id_num) AS id_nums
    FROM idnumrows
    GROUP BY 1
)
UPDATE us_split
SET county_id_nums = idnumgroups.id_nums
FROM idnumgroups
WHERE us_split.gid = idnumgroups.gid;

UPDATE us_histstateterr_polygon
SET splitid = us_split.gid
FROM us_split
WHERE ST_Equals(us_histstateterr_polygon.geom, us_split.geom);

WITH idnumrows AS (
    SELECT DISTINCT us_split.gid,
      id_num
    FROM us_split
    JOIN us_histstateterr_polygon
      ON us_split.gid = us_histstateterr_polygon.splitid
    UNION DISTINCT
    SELECT DISTINCT
      us_split.gid,
      id_num
    FROM us_split
    JOIN us_histstateterr_polygon
      ON splitid IS NULL
      AND ST_Contains(us_histstateterr_polygon.geom, us_split.geom)
), idnumgroups AS (
    SELECT DISTINCT
      gid,
      array_agg(id_num ORDER BY id_num) AS id_nums
    FROM idnumrows
    GROUP BY 1
)
UPDATE us_split
SET state_id_nums = idnumgroups.id_nums
FROM idnumgroups
WHERE us_split.gid = idnumgroups.gid;

-- Create and populate split topology

CREATE EXTENSION postgis_topology;
SELECT topology.CreateTopology('topologydata', 4326);

CREATE TABLE IF NOT EXISTS topologydata.us_split_topology
(
    gid serial NOT NULL,
    name character varying(20) COLLATE pg_catalog."default",
    id character varying(50) COLLATE pg_catalog."default",
    state_terr character varying(50) COLLATE pg_catalog."default",
    fips character varying(5) COLLATE pg_catalog."default",
    county_id_nums integer[],
    state_id_nums integer[],
    CONSTRAINT us_split_pkey PRIMARY KEY (gid)
);

SELECT topology.AddTopoGeometryColumn('topologydata', 'topologydata', 'us_split_topology', 'topogeometry', 'POLYGON') As new_layer_id;

INSERT INTO topologydata.us_split_topology (name, id, state_terr, fips, county_id_nums, state_id_nums, topogeometry)
SELECT name, id, state_terr, fips, county_id_nums, state_id_nums,
    topology.toTopoGeom(geom, 'topologydata', 1)
FROM us_split;

-- Combine splits back together into county and state topology layers

CREATE TABLE IF NOT EXISTS topologydata.us_histcounties_topology
(
    gid serial NOT NULL,
    id_num integer,
    name character varying(20) COLLATE pg_catalog."default",
    id character varying(50) COLLATE pg_catalog."default",
    state_terr character varying(50) COLLATE pg_catalog."default",
    fips character varying(5) COLLATE pg_catalog."default",
    version smallint,
    start_date date,
    end_date date,
    change character varying(254) COLLATE pg_catalog."default",
    citation character varying(254) COLLATE pg_catalog."default",
    start_n integer,
    end_n integer,
    area_sqmi numeric,
    cnty_type character varying(25) COLLATE pg_catalog."default",
    full_name character varying(50) COLLATE pg_catalog."default",
    cross_ref character varying(80) COLLATE pg_catalog."default",
    name_start character varying(40) COLLATE pg_catalog."default",
    CONSTRAINT us_histcounties_polygon_pkey PRIMARY KEY (gid)
);

SELECT topology.AddTopoGeometryColumn('topologydata', 'topologydata', 'us_histcounties_topology', 'topogeometry', 'POLYGON') As new_layer_id;

WITH idnumrows AS (
    SELECT unnest(county_id_nums) AS id_num,
    topogeometry
    FROM topologydata.us_split_topology
), idnumelements AS (
    SELECT DISTINCT id_num,
    GetTopoGeomElements(topogeometry) AS topogeometryelement
    FROM idnumrows
), idnumgroups AS (
    SELECT id_num,
    array_agg(topogeometryelement) AS topogeometryelements
    FROM idnumelements
    GROUP BY 1
)
INSERT INTO topologydata.us_histcounties_topology (id_num, name, id, state_terr, fips, version, start_date, end_date, change, citation, start_n, end_n, area_sqmi, cnty_type, full_name, cross_ref, name_start, topogeometry)
SELECT us_histcounties.id_num, name, id, state_terr, fips, version, start_date, end_date, change, citation, start_n, end_n, area_sqmi, cnty_type, full_name, cross_ref, name_start,
CreateTopoGeom('topologydata', 3, 2, topogeometryelements) AS topogeometry
FROM us_histcounties
JOIN idnumgroups
  ON us_histcounties.id_num = idnumgroups.id_num;

CREATE TABLE IF NOT EXISTS topologydata.us_histstateterr_topology
(
    gid serial NOT NULL,
    id_num integer,
    name character varying(20) COLLATE pg_catalog."default",
    id character varying(50) COLLATE pg_catalog."default",
    version smallint,
    start_date date,
    end_date date,
    change character varying(254) COLLATE pg_catalog."default",
    citation character varying(254) COLLATE pg_catalog."default",
    start_n integer,
    end_n integer,
    area_sqmi numeric,
    terr_type character varying(25) COLLATE pg_catalog."default",
    full_name character varying(50) COLLATE pg_catalog."default",
    abbr_name character varying(15) COLLATE pg_catalog."default",
    name_start character varying(40) COLLATE pg_catalog."default",
    CONSTRAINT us_histstateterr_polygon_pkey PRIMARY KEY (gid)
);

SELECT topology.AddTopoGeometryColumn('topologydata', 'topologydata', 'us_histstateterr_topology', 'topogeometry', 'POLYGON') As new_layer_id;

WITH idnumrows AS (
    SELECT unnest(state_id_nums) AS id_num,
    topogeometry
    FROM topologydata.us_split_topology
  WHERE state_id_nums IS NOT NULL
), idnumelements AS (
    SELECT DISTINCT id_num,
    GetTopoGeomElements(topogeometry) AS topogeometryelement
    FROM idnumrows
), idnumgroups AS (
    SELECT id_num,
    array_agg(topogeometryelement) AS topogeometryelements
    FROM idnumelements
    GROUP BY 1
)
INSERT INTO topologydata.us_histstateterr_topology (id_num, name, id, version, start_date, end_date, change, citation, start_n, end_n, area_sqmi, terr_type, full_name, abbr_name, name_start, topogeometry)
SELECT us_histstateterr.id_num, name, id, version, start_date, end_date, change, citation, start_n, end_n, area_sqmi, terr_type, full_name, abbr_name, name_start,
CreateTopoGeom('topologydata', 3, 3, topogeometryelements) AS topogeometry
FROM us_histstateterr
JOIN idnumgroups
  ON us_histstateterr.id_num = idnumgroups.id_num;

-- Determine edges and whether inner-outer (outstanding issues: Need to verify this works correctly. Do they have to be in order? What about outer inside inner?)

CREATE TABLE IF NOT EXISTS topologydata.us_histcounties_topology_edge
(
    gid serial NOT NULL,
    id_num integer NOT NULL,
    edge_id integer NOT NULL,
    edge_type character varying(20) NOT NULL,
    CONSTRAINT us_histcounties_topology_edge_pkey PRIMARY KEY (gid)
);

CREATE INDEX IF NOT EXISTS us_histcounties_topology_edge_id_num_idx
    ON topologydata.us_histcounties_topology_edge USING btree
    (id_num ASC NULLS LAST);

WITH faces AS (
    SELECT 
    id_num,
    (GetTopoGeomElements(topogeometry))[1] AS face_id
    FROM topologydata.us_histcounties_topology
), edges AS (
    SELECT DISTINCT
    id_num,
    face_id,
    edge_sequence,
    abs(edge_id) AS edge_id,
    row_number() OVER (PARTITION BY id_num ORDER BY face_id, edge_sequence, edge_id) AS row_number
    FROM faces, ST_GetFaceEdges('topologydata', face_id) AS t(edge_sequence, edge_id)
), interiorringcount AS (
    SELECT
    id_num,
    ST_NumInteriorRings((ST_Dump(ST_Multi(geom))).geom) AS interiorringcount
    FROM us_histcounties
), hasinteriorring AS (
    SELECT id_num
    FROM interiorringcount
    GROUP BY 1
    HAVING sum(interiorringcount) > 0
), exteriorringparts AS (
    SELECT us_histcounties.id_num,
      ST_ExteriorRing((ST_Dump(ST_Multi(geom))).geom) AS geom
    FROM us_histcounties
    JOIN hasinteriorring
      ON us_histcounties.id_num = hasinteriorring.id_num
), exteriorrings AS (
    SELECT id_num,
      ST_Union(geom) AS geom
    FROM exteriorringparts
    GROUP BY 1
)
INSERT INTO topologydata.us_histcounties_topology_edge (id_num, edge_id, edge_type)
SELECT DISTINCT edges.id_num,
edges.edge_id,
CASE
    WHEN exteriorrings.id_num IS NOT NULL THEN 'inner'
    ELSE 'outer'
END AS edge_type
FROM edges
LEFT JOIN edges otheredges
  ON edges.id_num = otheredges.id_num
  AND edges.edge_id = otheredges.edge_id
  AND edges.row_number <> otheredges.row_number
LEFT JOIN hasinteriorring
  ON edges.id_num = hasinteriorring.id_num
LEFT JOIN topologydata.edge_data
  ON hasinteriorring.id_num IS NOT NULL
  AND edges.edge_id = edge_data.edge_id
LEFT JOIN exteriorrings
  ON hasinteriorring.id_num = exteriorrings.id_num
  AND NOT ST_Contains(exteriorrings.geom, edge_data.geom)
WHERE otheredges.id_num IS NULL
ORDER BY 1, 2, 3;

CREATE TABLE IF NOT EXISTS topologydata.us_histstateterr_topology_edge
(
    gid serial NOT NULL,
    id_num integer NOT NULL,
    edge_id integer NOT NULL,
    edge_type character varying(20) NOT NULL,
    CONSTRAINT us_histstateterr_topology_edge_pkey PRIMARY KEY (gid)
);

CREATE INDEX IF NOT EXISTS us_histstateterr_topology_edge_id_num_idx
    ON topologydata.us_histstateterr_topology_edge USING btree
    (id_num ASC NULLS LAST);

WITH faces AS (
    SELECT 
    id_num,
    (GetTopoGeomElements(topogeometry))[1] AS face_id
    FROM topologydata.us_histstateterr_topology
), edges AS (
    SELECT DISTINCT
    id_num,
    face_id,
    edge_sequence,
    abs(edge_id) AS edge_id,
    row_number() OVER (PARTITION BY id_num ORDER BY face_id, edge_sequence, edge_id) AS row_number
    FROM faces, ST_GetFaceEdges('topologydata', face_id) AS t(edge_sequence, edge_id)
), interiorringcount AS (
    SELECT
    id_num,
    ST_NumInteriorRings((ST_Dump(ST_Multi(geom))).geom) AS interiorringcount
    FROM us_histstateterr
), hasinteriorring AS (
    SELECT id_num
    FROM interiorringcount
    GROUP BY 1
    HAVING sum(interiorringcount) > 0
), exteriorringparts AS (
    SELECT us_histstateterr.id_num,
      ST_ExteriorRing((ST_Dump(ST_Multi(geom))).geom) AS geom
    FROM us_histstateterr
    JOIN hasinteriorring
      ON us_histstateterr.id_num = hasinteriorring.id_num
), exteriorrings AS (
    SELECT id_num,
      ST_Union(geom) AS geom
    FROM exteriorringparts
    GROUP BY 1
)
INSERT INTO topologydata.us_histstateterr_topology_edge (id_num, edge_id, edge_type)
SELECT DISTINCT edges.id_num,
edges.edge_id,
CASE
    WHEN exteriorrings.id_num IS NOT NULL THEN 'inner'
    ELSE 'outer'
END AS edge_type
FROM edges
LEFT JOIN edges otheredges
  ON edges.id_num = otheredges.id_num
  AND edges.edge_id = otheredges.edge_id
  AND edges.row_number <> otheredges.row_number
LEFT JOIN hasinteriorring
  ON edges.id_num = hasinteriorring.id_num
LEFT JOIN topologydata.edge_data
  ON hasinteriorring.id_num IS NOT NULL
  AND edges.edge_id = edge_data.edge_id
LEFT JOIN exteriorrings
  ON hasinteriorring.id_num = exteriorrings.id_num
  AND NOT ST_Contains(exteriorrings.geom, edge_data.geom)
WHERE otheredges.id_num IS NULL
ORDER BY 1, 2, 3;
