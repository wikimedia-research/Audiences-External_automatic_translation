-- Generates Google translated pageviews daily
--
-- This job is responsible for filtering pageview data from the ${source_table}, 
-- and then aggregating it into interesting dimensions.
-- Those values are finally concatenated to previously computed data available in
-- ${archive_table}.
-- This dataset is inserted in a temporary external table which format is TSV
-- The end of the oozie job then moves this file to the archive table directory,
-- overwriting the exisiting file.
--
-- Parameters:
--     source_table      -- table containing source data
--     archive_table     -- Fully qualified table name where
--                          to find archived data.
--     temporary_directory
--                       -- Temporary directory to store computed data
--     year              -- year of the to-be-generated
--     month             -- month of the to-be-generated
--     day               -- day of the to-be-generated
--
--
-- Usage:
--     hive -f google_translated_pageviews_daily.hql
--         -d source_table=wmf.webrequest
--         -d archive_table=chelsyx.toledo_pageviews
--         -d temporary_directory=/tmp/toledo_pageviews
--         -d year=2019
--         -d month=3
--         -d day=1
--

-- Set compression codec to gzip to provide asked format
SET hive.exec.compress.output=true;
SET mapreduce.output.fileoutputformat.compress.codec=org.apache.hadoop.io.compress.GzipCodec;


-- Create a temporary table, then compute the new unique count
-- and concatenate it to archived data.
DROP TABLE IF EXISTS tmp_toledo_pageviews_${year}_${month}_${day};
CREATE EXTERNAL TABLE tmp_toledo_pageviews_${year}_${month}_${day} (
    `count`                bigint  COMMENT 'pageview count',
    `year`                 int     COMMENT 'Unpadded year of request',
    `month`                int     COMMENT 'Unpadded month of request',
    `day`                  int     COMMENT 'Unpadded day of request',
    `http_method`          string  COMMENT 'HTTP method',
    `http_status`          int     COMMENT 'HTTP status',
    `uri_host`             string  COMMENT 'URI host',
    `agent_type`           string  COMMENT 'user agent type',
    `access_method`        string  COMMENT 'Method used to accessing the site (mobile web|desktop)',
    `referer_host`         string  COMMENT 'Host from referer parsing',
    `referer_class`        string  COMMENT 'Indicates if a referer is internal, external or unknown.',
    `client_srp`           boolean COMMENT 'Whether client is search result page from referer parsing',
    `home_language`        string  COMMENT 'Home language',
    `source_language`      string  COMMENT 'Source language',
    `to_language`          string  COMMENT 'To language',
    `rurl_param`           string  COMMENT 'rurl parameter',
    `continent`            string  COMMENT 'Continent of the accessing agents (maxmind GeoIP database)',
    `country_code`         string  COMMENT 'Country iso code of the accessing agents (maxmind GeoIP database)',
    `country`              string  COMMENT 'Country (text) of the accessing agents (maxmind GeoIP database)'
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
LINES TERMINATED BY '\n'
LOCATION '${temporary_directory}'
;

WITH toledo_pageviews_${year}_${month}_${day} AS
(
    SELECT
        count(1) AS count,
        year,
        month,
        day,
        http_method,
        http_status,
        uri_host,
        agent_type,
        access_method,
        parse_url(referer, 'HOST') AS referer_host,
        referer_class,
        parse_url(referer, 'QUERY') LIKE '%client=srp%' AS client_srp,
        regexp_extract(parse_url(referer, 'QUERY'), '(^|[&?])hl=([^&]*)', 2) AS home_language,
        regexp_extract(parse_url(referer, 'QUERY'), '(^|[&?])sl=([^&]*)', 2) AS source_language,
        regexp_extract(parse_url(referer, 'QUERY'), '(^|[&?])tl=([^&]*)', 2) AS to_language,
        regexp_extract(parse_url(referer, 'QUERY'), '(^|[&?])rurl=([^&]*)', 2) AS rurl_param,
        geocoded_data['continent'] AS continent,
        geocoded_data['country_code'] AS country_code,
        geocoded_data['country'] AS country
    FROM ${source_table}
    WHERE is_pageview
        AND x_analytics_map['translationengine'] = 'GT'
        AND year=${year}
        AND month=${month}
        AND day=${day}
    GROUP BY
        year, month, day,
        http_method,
        http_status,
        uri_host,
        agent_type,
        access_method,
        parse_url(referer, 'HOST'),
        referer_class,
        parse_url(referer, 'QUERY') LIKE '%client=srp%',
        regexp_extract(parse_url(referer, 'QUERY'), '(^|[&?])hl=([^&]*)', 2),
        regexp_extract(parse_url(referer, 'QUERY'), '(^|[&?])sl=([^&]*)', 2),
        regexp_extract(parse_url(referer, 'QUERY'), '(^|[&?])tl=([^&]*)', 2),
        regexp_extract(parse_url(referer, 'QUERY'), '(^|[&?])rurl=([^&]*)', 2),
        geocoded_data['continent'],
        geocoded_data['country_code'],
        geocoded_data['country']
)
INSERT OVERWRITE TABLE tmp_toledo_pageviews_${year}_${month}_${day}
SELECT *
FROM
    (
        SELECT *
        FROM
            ${archive_table}
        WHERE NOT ((year = ${year})
            AND (month = ${month})
            AND (day = ${day}))

        UNION ALL

        SELECT *
        FROM
            toledo_pageviews_${year}_${month}_${day}
    ) old_union_new_toledo_pageviews
ORDER BY
    year,
    month,
    day,
    access_method,
    client_srp
-- Limit enforced by hive strict mapreduce setting.
-- 1000000000 == NO LIMIT !
LIMIT 1000000000
;

-- Drop temporary table (not needed anymore with hive 0.14)
DROP TABLE IF EXISTS tmp_toledo_pageviews_${year}_${month}_${day};