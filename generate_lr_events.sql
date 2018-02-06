-- All the SQL below is in aid of creating the new event table
-- from an input point geometry table
drop table los_2018_def_events_oh;

-- The transform statements are needed because the road layer was in EPSG: 3857
CREATE TABLE los_2018_def_events AS
-- We first need to get a candidate set of maybe-closest
-- streets, ordered by id and distance...
WITH ordered_nearest AS (
SELECT
  ST_GeometryN(ST_transform(streets.geom,3734),1) AS streets_geom,
  streets.gid AS streets_gid,
  streets.nlfid as streets_nlf_id,
  streets.ctl_begin as streets_ctl_begin,
  streets.ctl_end as streets_ctl_end,
  locations.geom AS locations_geom,
  locations.gid AS locations_gid,
  locations.los as locations_los,
  locations.ix_leg as locations_ix_leg,
  locations.direction as locations_direction,
  locations.on_road as locations_on_road,
  --subways.i
  locations.juris as locations_juris,
  locations."2013_loc" as locations_2013_loc,
  locations.on_fc as locations_on_fc,
  locations.ix_fc as locations_ix_fc,
  locations.on_fedaid as locations_fedaid,
  locations.assume_rd as locations_assume_rd,
  ST_Distance(ST_transform(streets.geom,3734), locations.geom) AS distance
FROM road_inventory_3857 streets
  JOIN los_2018_def locations
  ON ST_DWithin(st_transform(streets.geom,3734), locations.geom, 75)
  WHERE (streets.county_cd = 'LUC' or streets.county_cd = 'WOO') 
  AND (locations.juris <> 'Whiteford Township' AND locations.juris <> 'Bedford Township')  
ORDER BY locations_gid, distance ASC
)
-- We use the 'distinct on' PostgreSQL feature to get the first
-- street (the nearest) for each unique street gid. We can then
-- pass that one street into ST_LineLocatePoint along with
-- its candidate congestion location to calculate the measure.

SELECT
  DISTINCT ON (locations_gid)
  locations_gid,
  streets_gid,
  streets_nlfid
  ST_LineLocatePoint(streets_geom, locations_geom) AS measure,
  
  streets_ctl_begin,
  streets_ctl_end,
  distance
  locations_los,
  locations_ix_leg,
  locations_direction,
  locations_on_road,
  locations_juris,
  locations_2013_loc,
  locations_on_fc,
  locations_ix_fc,
  locations_fedaid,
  locations_assume_rd
FROM ordered_nearest;

-- Then use the begin and end log points with the measure
-- to calculate the log point of the event.

-- Primary keys are useful for visualization softwares
ALTER TABLE los_2018_def_events_oh ADD PRIMARY KEY (subways_gid);
alter table los_2018_def_events_oh add column meas double precision, add column fmeas double precision, add column tmeas double precision;
update los_2018_def_events_oh set meas = ROUND (cast((streets_ctl_begin + (streets_ctl_end - streets_ctl_begin)*measure) as numeric),3);
--this should work for cases where meas = streets_ctl_end or meas <> streets_ctl_begin or meas <> streets_ctl_end
--0.001 is too short, as it created some null geometries; 0.004 was the minimum that created non-null geometries for all rows in table
update los_2018_def_events_oh set fmeas = meas where streets_ctl_end - meas > 0.004;
update los_2018_def_events_oh set tmeas = meas + 0.004 where streets_ctl_end - meas > 0.004;

update los_2018_def_events_oh set fmeas = meas - 0.004 where meas - streets_ctl_begin > 0.004;
update los_2018_def_events_oh set tmeas = meas  where meas - streets_ctl_begin > 0.004;

update los_2018_def_events_oh set fmeas = streets_ctl_begin where streets_ctl_end - streets_ctl_begin <= 0.004;
update los_2018_def_events_oh set tmeas = streets_ctl_end where streets_ctl_end - streets_ctl_begin <= 0.004;


