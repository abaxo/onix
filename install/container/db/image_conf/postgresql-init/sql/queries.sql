/*
    Onix CMDB - Copyright (c) 2018-2019 by www.gatblau.org

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software distributed under
    the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
    either express or implied.
    See the License for the specific language governing permissions and limitations under the License.

    Contributors to this project, hereby assign copyright in this code to the project,
    to be licensed under the same terms as the rest of the code.
*/
DO
$$
BEGIN

/*
  find_items: find items that comply with the passed-in query parameters
 */
CREATE OR REPLACE FUNCTION find_items(
    tag_param text[], -- zero (null) or more tags
    attribute_param hstore, -- zero (null) or more key->value pair attributes
    status_param smallint, -- zero (null) or one status
    item_type_key_param character varying, -- zero (null) or one item type
    date_created_from_param timestamp(6) with time zone, -- none (null) or created from date
    date_created_to_param timestamp(6) with time zone, -- none (null) or created to date
    date_updated_from_param timestamp(6) with time zone, -- none (null) or updated from date
    date_updated_to_param timestamp(6) with time zone -- none (null) or updated to date
  )
  RETURNS TABLE(
    id bigint,
    key character varying,
    name character varying,
    description text,
    status smallint,
    item_type_id integer,
    meta jsonb,
    tag text[],
    attribute hstore,
    version bigint,
    created timestamp(6) with time zone,
    updated timestamp(6) with time zone,
    changedby character varying
  )
  LANGUAGE 'plpgsql'
  COST 100
  STABLE
AS $BODY$
DECLARE
  item_type_id_value smallint;

BEGIN
  IF NOT (item_type_key_param IS NULL) THEN
    SELECT it.id INTO item_type_id_value
    FROM item_type it
      INNER JOIN item i
        ON i.item_type_id = it.id
        AND it.key = item_type_key_param;
  END IF;

  RETURN QUERY SELECT
    i.id,
    i.key,
    i.name,
    i.description,
    i.status,
    i.item_type_id,
    i.meta,
    i.tag,
    i.attribute,
    i.version,
    i.created,
    i.updated,
    i.changedby
  FROM item i
  WHERE
  -- by item type
      (i.item_type_id = item_type_id_value OR item_type_id_value IS NULL)
  -- by status
  AND (i.status = status_param OR status_param IS NULL)
  -- by tags
  AND (i.tag @> tag_param OR tag_param IS NULL)
  -- by attributes (hstore)
  AND (i.attribute @> attribute_param OR attribute_param IS NULL)
  -- by created date range
  AND ((date_created_from_param <= i.created AND date_created_to_param > i.created) OR
      (date_created_from_param IS NULL AND date_created_to_param IS NULL) OR
      (date_created_from_param IS NULL AND date_created_to_param > i.created) OR
      (date_created_from_param <= i.created AND date_created_to_param IS NULL))
  -- by updated date range
  AND ((date_updated_from_param <= i.updated AND date_updated_to_param > i.updated) OR
      (date_updated_from_param IS NULL AND date_updated_to_param IS NULL) OR
      (date_updated_from_param IS NULL AND date_updated_to_param > i.updated) OR
      (date_updated_from_param <= i.updated AND date_updated_to_param IS NULL));
END
$BODY$;

ALTER FUNCTION find_items(
    text[],
    hstore,
    smallint,
    character varying,
    timestamp(6) with time zone, -- created from
    timestamp(6) with time zone, -- created to
    timestamp(6) with time zone, -- updated from
    timestamp(6) with time zone -- updated to
  )
  OWNER TO onix;

/*
  find_links: find links that comply with the passed-in query parameters
 */
CREATE OR REPLACE FUNCTION find_links(
  start_item_key_param character varying, -- zero (null) or one start item
  end_item_key_param character varying, -- zero (null) or one end item
  tag_param text[], -- zero (null) or more tags
  attribute_param hstore, -- zero (null) or more key->value pair attributes
  link_type_key_param character varying, -- zero (null) or one link type
  date_created_from_param timestamp(6) with time zone, -- none (null) or created from date
  date_created_to_param timestamp(6) with time zone, -- none (null) or created to date
  date_updated_from_param timestamp(6) with time zone, -- none (null) or updated from date
  date_updated_to_param timestamp(6) with time zone -- none (null) or updated to date
)
RETURNS TABLE(
    id bigint,
    key character varying,
    link_type_key character varying,
    start_item_key character varying,
    end_item_key character varying,
    description text,
    meta jsonb,
    tag text[],
    attribute hstore,
    version bigint,
    created TIMESTAMP(6) WITH TIME ZONE,
    updated timestamp(6) WITH TIME ZONE,
    changedby CHARACTER VARYING
  )
  LANGUAGE 'plpgsql'
  COST 100
  STABLE
AS $BODY$
DECLARE
  link_type_id_value smallint;

BEGIN
  IF NOT (link_type_key_param IS NULL) THEN
    SELECT lt.id INTO link_type_id_value
    FROM link_type lt
      INNER JOIN link l
        ON l.link_type_id = lt.id
        AND lt.key = link_type_key_param;
  END IF;

  RETURN QUERY SELECT
    l.id,
    l.key,
    lt.key as link_type_key,
    start_item.key AS start_item_key,
    end_item.key AS end_item_key,
    l.description,
    l.meta,
    l.tag,
    l.attribute,
    l.version,
    l.created,
    l.updated,
    l.changedby
  FROM link l
    INNER JOIN item start_item
      ON l.start_item_id = start_item.id
    INNER JOIN item end_item
      ON l.end_item_id = end_item.id
    INNER JOIN link_type lt
      ON l.link_type_id = lt.id
  WHERE
   -- by link type
   (l.link_type_id = link_type_id_value OR link_type_id_value IS NULL)
   -- by start item
   AND (start_item.key = start_item_key_param OR start_item_key_param IS NULL)
   -- by end item
   AND (end_item.key = end_item_key_param OR end_item_key_param IS NULL)
   -- by tags
   AND (l.tag @> tag_param OR tag_param IS NULL)
   -- by attributes (hstore)
   AND (l.attribute @> attribute_param OR attribute_param IS NULL)
   -- by created date range
   AND ((date_created_from_param <= l.created AND date_created_to_param > l.created) OR
        (date_created_from_param IS NULL AND date_created_to_param IS NULL) OR
        (date_created_from_param IS NULL AND date_created_to_param > l.created) OR
        (date_created_from_param <= l.created AND date_created_to_param IS NULL))
   -- by updated date range
   AND ((date_updated_from_param <= l.updated AND date_updated_to_param > l.updated) OR
        (date_updated_from_param IS NULL AND date_updated_to_param IS NULL) OR
        (date_updated_from_param IS NULL AND date_updated_to_param > l.updated) OR
        (date_updated_from_param <= l.updated AND date_updated_to_param IS NULL));
END
$BODY$;

ALTER FUNCTION find_links(
  character varying,
  character varying,
  text[],
  hstore,
  character varying,
  timestamp(6) with time zone, -- created from
  timestamp(6) with time zone, -- created to
  timestamp(6) with time zone, -- updated from
  timestamp(6) with time zone -- updated to
)
OWNER TO onix;

/*
  find_item_types: find item types that comply with the passed-in query parameters
 */
CREATE OR REPLACE FUNCTION find_item_types(
    attr_valid_param hstore, -- zero (null) or more key->value pair attributes
    system_param boolean, -- (null) for any or true / false
    date_created_from_param timestamp(6) with time zone, -- none (null) or created from date
    date_created_to_param timestamp(6) with time zone, -- none (null) or created to date
    date_updated_from_param timestamp(6) with time zone, -- none (null) or updated from date
    date_updated_to_param timestamp(6) with time zone -- none (null) or updated to date
  )
  RETURNS TABLE(
    id integer,
    key character varying,
    name character varying,
    description text,
    attr_valid hstore,
    system boolean,
    version bigint,
    created timestamp(6) with time zone,
    updated timestamp(6) with time zone,
    changedby character varying
  )
  LANGUAGE 'plpgsql'
  COST 100
  STABLE
AS $BODY$
BEGIN
  RETURN QUERY SELECT
     i.id,
     i.key,
     i.name,
     i.description,
     i.attr_valid,
     i.system,
     i.version,
     i.created,
     i.updated,
     i.changedby
  FROM item_type i
  WHERE
  -- by system flag
     (i.system = system_param OR system_param IS NULL)
  -- by attributes (hstore)
  AND (i.attr_valid @> attr_valid_param OR attr_valid_param IS NULL)
  -- by created date range
  AND ((date_created_from_param <= i.created AND date_created_to_param > i.created) OR
      (date_created_from_param IS NULL AND date_created_to_param IS NULL) OR
      (date_created_from_param IS NULL AND date_created_to_param > i.created) OR
      (date_created_from_param <= i.created AND date_created_to_param IS NULL))
  -- by updated date range
  AND ((date_updated_from_param <= i.updated AND date_updated_to_param > i.updated) OR
      (date_updated_from_param IS NULL AND date_updated_to_param IS NULL) OR
      (date_updated_from_param IS NULL AND date_updated_to_param > i.updated) OR
      (date_updated_from_param <= i.updated AND date_updated_to_param IS NULL));
END
$BODY$;

ALTER FUNCTION find_item_types(
  hstore,
  boolean,
  timestamp(6) with time zone, -- created from
  timestamp(6) with time zone, -- created to
  timestamp(6) with time zone, -- updated from
  timestamp(6) with time zone -- updated to
)
OWNER TO onix;

/*
  find_link_types: find link types that comply with the passed-in query parameters
 */
CREATE OR REPLACE FUNCTION find_link_types(
    attr_valid_param hstore, -- zero (null) or more key->value pair attributes
    system_param boolean, -- (null) for any or true / false
    date_created_from_param timestamp(6) with time zone, -- none (null) or created from date
    date_created_to_param timestamp(6) with time zone, -- none (null) or created to date
    date_updated_from_param timestamp(6) with time zone, -- none (null) or updated from date
    date_updated_to_param timestamp(6) with time zone -- none (null) or updated to date
  )
  RETURNS TABLE(
    id integer,
    key character varying,
    name character varying,
    description text,
    attr_valid hstore,
    system boolean,
    version bigint,
    created timestamp(6) with time zone,
    updated timestamp(6) with time zone,
    changedby character varying
  )
  LANGUAGE 'plpgsql'
  COST 100
  STABLE
AS $BODY$
BEGIN
  RETURN QUERY SELECT
     l.id,
     l.key,
     l.name,
     l.description,
     l.attr_valid,
     l.system,
     l.version,
     l.created,
     l.updated,
     l.changedby
  FROM link_type l
  WHERE
  -- by system flag
      (l.system = system_param OR system_param IS NULL)
  -- by attributes (hstore)
  AND (l.attr_valid @> attr_valid_param OR attr_valid_param IS NULL)
  -- by created date range
  AND ((date_created_from_param <= l.created AND date_created_to_param > l.created) OR
      (date_created_from_param IS NULL AND date_created_to_param IS NULL) OR
      (date_created_from_param IS NULL AND date_created_to_param > l.created) OR
      (date_created_from_param <= l.created AND date_created_to_param IS NULL))
  -- by updated date range
  AND ((date_updated_from_param <= l.updated AND date_updated_to_param > l.updated) OR
      (date_updated_from_param IS NULL AND date_updated_to_param IS NULL) OR
      (date_updated_from_param IS NULL AND date_updated_to_param > l.updated) OR
      (date_updated_from_param <= l.updated AND date_updated_to_param IS NULL));
END
$BODY$;

ALTER FUNCTION find_link_types(
  hstore,
  boolean,
  timestamp(6) with time zone, -- created from
  timestamp(6) with time zone, -- created to
  timestamp(6) with time zone, -- updated from
  timestamp(6) with time zone -- updated to
)
OWNER TO onix;

/*
  find_items_audit: find audit records for items that comply with the passed-in query parameters
 */
CREATE OR REPLACE FUNCTION find_items_audit(
  item_key_param character varying,
  date_changed_from_param timestamp(6) with time zone, -- none (null) or updated from date
  date_changed_to_param timestamp(6) with time zone -- none (null) or updated to date
)
RETURNS TABLE(
    operation char,
    change_date timestamp(6) with time zone,
    id bigint,
    key character varying,
    name character varying,
    description text,
    status smallint,
    item_type_id integer,
    meta jsonb,
    tag text[],
    attribute hstore,
    version bigint,
    created timestamp(6) with time zone,
    updated timestamp(6) with time zone,
    changedby character varying
  )
  LANGUAGE 'plpgsql'
  COST 100
  STABLE
AS $BODY$
BEGIN
  RETURN QUERY SELECT
    i.operation,
    i.change_date,
    i.id,
    i.key,
    i.name,
    i.description,
    i.status,
    i.item_type_id,
    i.meta,
    i.tag,
    i.attribute,
    i.version,
    i.created,
    i.updated,
    i.changedby
  FROM item_audit i
  WHERE i.key = item_key_param
  -- by change date range
  AND ((date_changed_from_param <= i.change_date AND date_changed_to_param > i.change_date) OR
      (date_changed_from_param IS NULL AND date_changed_to_param IS NULL) OR
      (date_changed_from_param IS NULL AND date_changed_to_param > i.change_date) OR
      (date_changed_from_param <= i.change_date AND date_changed_to_param IS NULL));
END
$BODY$;

ALTER FUNCTION find_items_audit(
  character varying, -- item natural key
  timestamp(6) with time zone, -- change date from
  timestamp(6) with time zone -- change date to
)
OWNER TO onix;

/*
  find_links_audit: find audit records for links that comply with the passed-in query parameters
 */
CREATE OR REPLACE FUNCTION find_links_audit(
    link_key_param character varying,
    date_changed_from_param timestamp(6) with time zone, -- none (null) or updated from date
    date_changed_to_param timestamp(6) with time zone -- none (null) or updated to date
  )
  RETURNS TABLE(
    operation char,
    change_date timestamp(6) with time zone,
    id bigint,
    key character varying,
    description text,
    link_type_key character varying,
    start_item_key character varying,
    end_item_key character varying,
    meta jsonb,
    tag text[],
    attribute hstore,
    version bigint,
    created timestamp(6) with time zone,
    updated timestamp(6) with time zone,
    changedby character varying
  )
  LANGUAGE 'plpgsql'
  COST 100
  STABLE
AS $BODY$
BEGIN
  RETURN QUERY SELECT
     l.operation,
     l.change_date,
     l.id,
     l.key,
     l.description,
     lt.key as link_type_key,
     start_item.key AS start_item_key,
     end_item.key AS end_item_key,
     l.meta,
     l.tag,
     l.attribute,
     l.version,
     l.created,
     l.updated,
     l.changedby
  FROM link_audit l
    INNER JOIN item start_item
      ON l.start_item_id = start_item.id
    INNER JOIN item end_item
      ON l.end_item_id = end_item.id
    INNER JOIN link_type lt
      ON l.link_type_id = lt.id
  WHERE l.key = link_key_param
  -- by change_date range
  AND ((date_changed_from_param <= l.change_date AND date_changed_to_param > l.change_date) OR
      (date_changed_from_param IS NULL AND date_changed_to_param IS NULL) OR
      (date_changed_from_param IS NULL AND date_changed_to_param > l.change_date) OR
      (date_changed_from_param <= l.change_date AND date_changed_to_param IS NULL));
END
$BODY$;

ALTER FUNCTION find_links_audit(
  character varying, -- item natural key
  timestamp(6) with time zone, -- change date from
  timestamp(6) with time zone -- change date to
)
OWNER TO onix;

/*
  get_links_from_item_count: find the number of links of a particular type that are associated with an start item.
     Can use the link attributes to filter the result.
 */
CREATE OR REPLACE FUNCTION get_links_from_item_count(
    item_key_param character varying, -- item natural key
    attribute_param hstore -- filter for links
  )
  RETURNS INTEGER
  LANGUAGE 'plpgsql'
  COST 100
  STABLE
AS $BODY$
DECLARE
  link_count integer;
BEGIN
  RETURN (
    SELECT COUNT(*) INTO link_count
    FROM link l
    INNER JOIN item i
       ON l.start_item_id = i.id
    WHERE i.key = item_key_param
    -- by attributes (hstore)
    AND (l.attribute @> attribute_param OR attribute_param IS NULL)
  );
END
$BODY$;

ALTER FUNCTION get_links_from_item_count(
  character varying, -- item natural key
  hstore -- filter for links
)
OWNER TO onix;

/*
  get_links_to_item_count: find the number of links of a particular type that are associated with an end item.
     Can use the link attributes to filter the result.
 */
CREATE OR REPLACE FUNCTION get_links_to_item_count(
    item_key_param character varying, -- item natural key
    attribute_param hstore -- filter for links
  )
  RETURNS INTEGER
  LANGUAGE 'plpgsql'
  COST 100
  STABLE
AS $BODY$
DECLARE
  link_count integer;
BEGIN
  RETURN (
    SELECT COUNT(*) INTO link_count
    FROM link l
      INNER JOIN item i
        ON l.end_item_id = i.id
    WHERE i.key = item_key_param
    -- by attributes (hstore)
    AND (l.attribute @> attribute_param OR attribute_param IS NULL)
  );
END
$BODY$;

ALTER FUNCTION get_links_to_item_count(
  character varying, -- item natural key
  hstore -- filter for links
)
OWNER TO onix;

END
$$;