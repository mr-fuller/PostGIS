-- All the SQL below is in aid of creating the new event table
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
  subways.geom AS subways_geom,
  subways.gid AS subways_gid,
  ST_Distance(ST_transform(streets.geom,3734), subways.geom) AS distance
FROM road_inventory_3857 streets
  JOIN los_2018_def subways
  ON ST_DWithin(st_transform(streets.geom,3734), subways.geom, 75)
ORDER BY subways_gid, distance ASC
)
-- We use the 'distinct on' PostgreSQL feature to get the first
-- street (the nearest) for each unique street gid. We can then
-- pass that one street into ST_LineLocatePoint along with
-- its candidate subway station to calculate the measure.

SELECT
  DISTINCT ON (subways_gid)
  subways_gid,
  streets_gid,
  streets_nlfid
  ST_LineLocatePoint(streets_geom, subways_geom) AS measure,
  streets_ctl_begin,
  streets_ctl_end,
  distance
FROM ordered_nearest;

-- Then use the begin and end log points with the measure
-- to calculate the log point of the event.

alter table los_2018_def_events add column ctl_pt
update table ctl_pt = streets_ctl_begin + measure * (streets_ctl_end - streets_ctl_begin)

-- Primary keys are useful for visualization softwares
ALTER TABLE los_2018_def_events ADD PRIMARY KEY (subways_gid);
