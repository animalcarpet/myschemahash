/****************************************************************************/
-- myschemahash

-- HASHING CHECK FOR SCHEMA CHANGES
-- Get a SHA-1 for schema objects (not data). Does not include 
-- tablespace and partition definitions. 
-- Allows match against partial value to save typing as
-- 8 characters will give 16^8 combinations.
-- Requires MyTAP

-- This version 5.7.6 and up
-- remove 'datetime_precision' for MySQL < 5.6.4
-- remove 'generation_expression' for MySQL < for 5.7.6

-- USE:
-- just get the hash
-- SELECT tap.myschemahash('dbname');

-- 'prettier' TAP version
-- SELECT tap.myschemahash_get('dbname');

-- TAP assertion to compare hash to known value
-- SELECT tap.myschemahash_is('dbname','abcdef123');


USE tap;

DELIMITER //


-- bundle all top level existence checks into one function
DROP FUNCTION IF EXISTS _has //
CREATE FUNCTION _has(otype VARCHAR(64), oname VARCHAR(64))
RETURNS BOOLEAN
SQL SECURITY DEFINER 
LANGUAGE SQL DETERMINISTIC READS SQL DATA
BEGIN
  DECLARE ret BOOLEAN;
  
  CASE otype
    WHEN 'schema' THEN
      SELECT 1 INTO ret
      FROM `information_schema`.`schemata` 
      WHERE `schema_name` = oname; 
    WHEN 'event' THEN
      SELECT 1 INTO ret
      FROM `information_schema`.`events` 
      WHERE `event_name` = oname; 
  END CASE;

  RETURN COALESCE(ret,0);
END //


DROP FUNCTION IF EXISTS myschemahash //
CREATE FUNCTION myschemahash(sname VARCHAR(64))
RETURNS CHAR(40)
SQL SECURITY DEFINER 
LANGUAGE SQL DETERMINISTIC READS SQL DATA
BEGIN
  DECLARE ret CHAR(40);
  -- resignal and deal with in calling functions
  DECLARE EXIT HANDLER FOR 1260 RESIGNAL;

  SELECT SHA1(GROUP_CONCAT(sha)) INTO ret
  FROM 
    (
      -- TABLES
      (SELECT SHA1(GROUP_CONCAT(SHA1(CONCAT_WS('',
         `table_catalog`,`table_schema`,`table_name`,`table_type`,
         `engine`,`version`,`row_format`,`table_collation`,`create_options`,
         `table_comment`)))) AS sha
       FROM `information_schema`.`tables`
       WHERE `table_schema` = sname
       AND `table_type` = 'BASE TABLE'
       ORDER BY `table_name` ASC)
    UNION ALL
     -- COLUMNS
      (SELECT SHA1(GROUP_CONCAT(SHA1(CONCAT_WS('',
        `table_catalog`,`table_schema`,`table_name`,`column_name`,
        `ordinal_position`,`column_default`,`is_nullable`,`data_type`,`character_set_name`,
        `character_maximum_length`,
        `character_octet_length`,`numeric_precision`,
        `numeric_scale`,`datetime_precision`,`collation_name`,`column_type`,
        `column_key`,`extra`,`privileges`,`column_comment`,
	`datetime_precision`,    -- >= 5.6.4
	`generation_expression`  -- >= 5.7.6
	)))) AS sha
      FROM `information_schema`.`columns`
      WHERE `table_schema` = sname
      ORDER BY `table_name` ASC,`ordinal_position` ASC)
  UNION ALL
     -- CONSTRAINTS
      (SELECT SHA1(GROUP_CONCAT(SHA1(CONCAT_WS('',
        `constraint_catalog`,`constraint_schema`,`constraint_name`,
        `unique_constraint_catalog`,`unique_constraint_schema`,`unique_constraint_name`,
        `match_option`,`update_rule`,`delete_rule`,`table_name`,
	`referenced_table_name`)))) AS sha
      FROM `information_schema`.`referential_constraints`
      WHERE `constraint_schema` = sname
      ORDER BY `table_name` ASC,`constraint_name` ASC)
  UNION ALL
    -- INDEXES
      (SELECT SHA1(GROUP_CONCAT(SHA1(CONCAT_WS('',
        `table_catalog`,`table_schema`,`table_name`,`index_name`,`non_unique`,
        `index_schema`,`index_name`,`seq_in_index`,`column_name`,`collation`,`cardinality`,
        `sub_part`,`packed`,`nullable`,`index_type`,`comment`,
	`index_comment`)))) AS sha
      FROM `information_schema`.`statistics`
      WHERE `table_schema` = sname
      ORDER BY `table_name` ASC,`index_name` ASC)
  UNION ALL
     -- VIEWS (covers some of the same as above)
      (SELECT SHA1(GROUP_CONCAT(SHA1(CONCAT_WS('',
        `table_catalog`,`table_schema`,`table_name`,`view_definition`,
        `check_option`,`is_updatable`,`definer`,
	`security_type`)))) AS sha
      FROM `information_schema`.`views`
      WHERE `table_schema` = sname
      ORDER BY `table_name` ASC)
    UNION ALL
     -- ROUTINES
       (SELECT SHA1(GROUP_CONCAT(SHA1(CONCAT_WS('',
         `routine_catalog`,`routine_schema`,`routine_name`,
            -- NB CML is broken in 5.7 (https://bugs.mysql.com/bug.php?id=88385)
         `routine_type`,`data_type`, `character_maximum_length`,
         `character_octet_length`,`numeric_precision`, `numeric_scale`,
         `datetime_precision`,`character_set_name`,`collation_name`,
         `dtd_identifier`,`routine_body`,`routine_definition`,
         `external_name`,`external_language`,`parameter_style`,
         `sql_data_access`,`sql_path`,`security_type`,`parameter_style`,
         `is_deterministic`,`security_type`,`sql_mode`,
         `routine_comment`,`definer`,
	 `database_collation`)))) AS sha
      FROM `information_schema`.`routines`
      WHERE `routine_schema` = sname
      ORDER BY `routine_name` ASC)
  UNION ALL
   -- PARAMETERS
      (SELECT SHA1(GROUP_CONCAT(SHA1(CONCAT_WS('',
         `specific_catalog`,`specific_schema`,`specific_name`,
         `ordinal_position`,`parameter_mode`,`parameter_name`,`data_type`,
         `character_maximum_length`,
         `character_octet_length`,`numeric_precision`,
         `numeric_scale`,`datetime_precision`,`character_set_name`,
         `collation_name`,`dtd_identifier`,
	 `routine_type`)))) AS sha
      FROM `information_schema`.`parameters`
      WHERE `specific_schema` = sname
      ORDER BY `specific_name` ASC, `ordinal_position` ASC)
  UNION ALL
     -- EVENTS
      (SELECT SHA1(GROUP_CONCAT(SHA1(CONCAT_WS('',
        `event_catalog`,`event_schema`,`event_name`,`definer`,`time_zone`,
        `event_body`,`event_definition`,`event_type`,`execute_at`,`interval_value`,
        `interval_field`,`sql_mode`,`starts`,`ends`,`status`,`on_completion`,
        `event_comment`,`originator`,
	`database_collation`)))) AS sha
      FROM `information_schema`.`events`
      WHERE `event_schema` = sname
      ORDER BY `event_name` ASC)
  UNION ALL
    -- TRIGGERS
      (SELECT SHA1(GROUP_CONCAT(SHA1(CONCAT_WS('',
        `trigger_catalog`,`trigger_schema`,`trigger_name`,`event_manipulation`,
        `event_object_catalog`,`event_object_schema`,`event_object_table`,`action_order`,
        `action_condition`,`action_statement`,`action_orientation`,`action_timing`,
        `action_reference_old_table`,`action_reference_new_table`,`action_reference_old_row`,
        `action_reference_new_row`,`sql_mode`,`definer`,`database_collation`)
      ))) AS sha
      FROM `information_schema`.`triggers`
      WHERE `trigger_schema` = sname
      ORDER BY `event_object_table` ASC,`trigger_name` ASC)
  ) objects;

  RETURN COALESCE(ret, NULL);
END //

DROP FUNCTION IF EXISTS myschemahash_is //
CREATE FUNCTION myschemahash_is(sname VARCHAR(64), sha1 VARCHAR(40))
RETURNS TEXT
SQL SECURITY DEFINER
LANGUAGE SQL DETERMINISTIC READS SQL DATA
BEGIN
  DECLARE gcml INT;
  DECLARE msg VARCHAR(82);
  DECLARE CONTINUE HANDLER FOR 1321
  BEGIN
    SELECT @@SESSION.group_concat_max_len INTO gcml;
    SET msg  = CONCAT('GROUP_CONCAT_MAX_LEN = ', gcml, ', SET @@group_concat_max_len = a_very_big_number;');
    RESIGNAL SET MESSAGE_TEXT = msg, MYSQL_ERRNO = 45000;
  END;
 
  SET @description = CONCAT('Schema `', sname, 
      '` definition should match supplied SHA-1 hash');
 
  IF NOT _has('schema',sname) THEN
    RETURN CONCAT('not ok: ', @description , '\n',
      CONCAT('Bail Out! Schema `', sname ,'` does not exist'));
  END IF;

  IF NOT sha1 REGEXP '^[a-fA-F0-9]{1,40}$' THEN
    RETURN CONCAT('not ok: ', @description , '\n',
      diag(CONCAT_WS('','    SHA-1 must be hexadecimal and no more than 40 characters\n\n    have: ', sha1)));
  END IF;

  -- NB length of supplied value not of a SHA-1
  RETURN eq(LEFT(myschemahash(sname), LENGTH(sha1)), sha1, @description);
END //


DROP FUNCTION IF EXISTS myschemahash_get //
CREATE FUNCTION myschemahash_get(sname VARCHAR(64))
RETURNS TEXT
SQL SECURITY DEFINER
LANGUAGE SQL DETERMINISTIC READS SQL DATA
BEGIN
  DECLARE gcml INT;
  DECLARE msg VARCHAR(82);
  DECLARE CONTINUE HANDLER FOR 1321
  BEGIN
    SELECT @@SESSION.group_concat_max_len INTO gcml;
    SET msg  = CONCAT('GROUP_CONCAT_MAX_LEN = ', gcml, ', SET @@group_concat_max_len = a_very_big_number;');
    RESIGNAL SET MESSAGE_TEXT = msg, MYSQL_ERRNO = 45000;
  END;

  SET @description = CONCAT('Schema `', sname, 
      '` SHA-1 hash: ');
 
  IF NOT _has('schema',sname) THEN
    RETURN CONCAT('not ok: ', @description , '\n',
      CONCAT('Bail Out! Schema `', sname ,'` does not exist'));
  END IF;

  -- NB length of supplied value not of a SHA-1
  RETURN CONCAT(@description, myschemahash(sname));
END //

DELIMITER ;

