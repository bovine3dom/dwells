 -- clickhouse
WITH
-- calculate the fraction of journey time each individual rail service is stopped for
trip_stats AS
(
    SELECT
    sane_route_id,
    trip_id,
    sum(dateDiff('minutes', arrival_time, departure_time)) AS dwell,
    dateDiff('minutes', min(departure_time), max(arrival_time)) AS journey_time
    FROM transitous_everything_20261018_real_edgelist_fahrtle2
    WHERE route_type = 1 OR route_type BETWEEN 100 AND 199
    GROUP BY sane_route_id, trip_id
    HAVING journey_time > 0 AND dwell > 0 AND count() > 1
),
-- work out where they stop
trip_stops AS
(
    SELECT
    sane_route_id,
    trip_id,
    groupUniqArray((stop_lat, stop_lon)) AS stops
    FROM transitous_everything_20261018_real_edgelist_fahrtle2
    WHERE route_type = 1 OR route_type BETWEEN 100 AND 199
    GROUP BY sane_route_id, trip_id
)
SELECT
toUInt32(intDiv(h3_t, 4294967296)) AS index_upper,
toUInt32(h3_t % 4294967296) AS index_lower,
avg(stopped_perc) AS value
FROM
(
    -- distribute the journey times back to the stops
    SELECT
    geoToH3(stop.1, stop.2, 6) AS h3_t,
    stats.dwell / stats.journey_time AS stopped_perc
    FROM trip_stats AS stats
    INNER JOIN trip_stops AS points USING (sane_route_id, trip_id)
    ARRAY JOIN points.stops AS stop
)
GROUP BY h3_t
INTO OUTFILE '/home/olie/projects/H3-MON/www/data/dwell.arrow'
TRUNCATE
SETTINGS output_format_arrow_compression_method = 'none'
FORMAT Arrow
;
