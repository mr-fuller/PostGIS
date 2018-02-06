--generate lrs events for michigan locations (because Michigan has a different schema)
--drop table los_2018_def_events;
drop table los_2018_def_events_mi;

-- All the SQL below is in aid of creating the new event table
CREATE TABLE los_2018_def_events_mi AS
-- We first need to get a candidate set of maybe-closest
-- streets, ordered by id and distance...
WITH ordered_nearest AS (
SELECT
  ST_GeometryN(ST_transform(streets.geom,3734),1) AS streets_geom,
  streets.gid AS streets_gid,
  streets.pr as streets_nlf_id,
  streets.bmp as streets_ctl_begin,
  streets.emp as streets_ctl_end,
  subways.geom AS subways_geom,
  subways.gid AS subways_gid,
  --subways.*,
  subways.los as subways_los,
  subways.ix_leg as subways_ix_leg,
  subways.direction as subways_direction,
  subways.on_road as subways_on_road,
  --subways.i
  subways.juris as subways_juris,
  subways."2013_loc" as subways_2013_loc,
  subways.on_fc as subways_on_fc,
  subways.ix_fc as subways_ix_fc,
  subways.on_fedaid as subways_fedaid,
  subways.assume_rd as subways_assume_rd,
  ST_Distance(ST_transform(streets.geom,3734), subways.geom) AS distance
FROM allroads_miv14a_3857 streets
  JOIN los_2018_def subways
  ON ST_DWithin(st_transform(streets.geom,3734), subways.geom, 75)
  --this limits queried roads to Monroe County (FIPS 115), or at least the ones in Monroe county we needed
  where streets.countyl = 115 AND (subways.juris = 'Whiteford Township' OR subways.juris = 'Bedford Township')  
ORDER BY subways.gid, distance ASC
)
-- We use the 'distinct on' PostgreSQL feature to get the first
-- street (the nearest) for each unique street gid. We can then
-- pass that one street into ST_LineLocatePoint along with
-- its candidate subway station to calculate the measure.
SELECT
  DISTINCT ON (subways_gid)
  subways_gid,
  streets_gid,
  streets_nlf_id,
  ST_LineLocatePoint(streets_geom, subways_geom) AS measure,
  --streets_ctl_begin + (streets_ctl_end-streets_ctl_begin)* measure AS ctl_point,
  streets_ctl_begin,
  streets_ctl_end,
  distance,
  subways_los,
  subways_ix_leg,
  subways_direction,
  subways_on_road,
  subways_juris,
  subways_2013_loc,
  subways_on_fc,
  subways_ix_fc,
  subways_fedaid,
  subways_assume_rd
  
FROM ordered_nearest;

-- Primary keys are useful for visualization softwares
ALTER TABLE los_2018_def_events_mi ADD PRIMARY KEY (subways_gid);
alter table los_2018_def_events_mi add column meas double precision, add column fmeas double precision, add column tmeas double precision;
update los_2018_def_events_mi set meas = ROUND (cast((streets_ctl_begin + (streets_ctl_end - streets_ctl_begin)*measure) as numeric),3);
--this should work for cases where meas = streets_ctl_end or meas <> streets_ctl_begin or meas <> streets_ctl_end
--0.001 might be too short, as it created some null geometries; 0.005 worked, optimize later
update los_2018_def_events_mi set fmeas = meas;
update los_2018_def_events_mi set tmeas = meas + 0.005; 
update los_2018_def_events_mi set fmeas = meas - 0.005 where meas = streets_ctl_end;
update los_2018_def_events_mi set tmeas = fmeas + 0.005 where meas = streets_ctl_end;


