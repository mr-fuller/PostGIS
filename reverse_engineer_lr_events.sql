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
  locations.geom AS locations_geom,
  locations.gid AS locations_gid,
  ST_Distance(ST_transform(streets.geom,3734), locations.geom) AS distance
FROM road_inventory_3857 streets
  JOIN los_2018_def locations
  ON ST_DWithin(st_transform(streets.geom,3734), locations.geom, 75)
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
FROM ordered_nearest;

-- Then use the begin and end log points with the measure
-- to calculate the log point of the event.

alter table los_2018_def_events add column ctl_pt float, bmp float, emp float
update table set ctl_pt = streets_ctl_begin + measure * (streets_ctl_end - streets_ctl_begin);

-- turn points into really small lines, first the case where ctl_pt isn't on a boundary
update table set bmp = ctl_pt;
update table set emp = bmp + 0.001;
--case where point is on the start of the linear reference segment
update table set bmp = ctl_pt + 0.001 where ctl_pt = streets_ctl_begin;
update table set emp = bmp + 0.001 where ctl_pt = streets_ctl_begin;
--case where point is on the end of the linear reference segment
update table set emp = ctl_pt - 0.001 where ctl_pt = streets_ctl_end;
update table set bmp = emp + 0.001 where ctl_pt = streets_ctl_end;

-- Primary keys are useful for visualization softwares
ALTER TABLE los_2018_def_events ADD PRIMARY KEY (locations_gid);
