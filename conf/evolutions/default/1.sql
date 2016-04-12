# --- Map Roulette Scheme

# --- !Ups
-- Function that simply creates an index if it doesn't already exist
CREATE OR REPLACE FUNCTION create_index_if_not_exists(t_name text, i_name text, index_sql text, unq boolean default false) RETURNS void as $$
DECLARE
  full_index_name varchar;;
  schema_name varchar;;
  unqValue varchar;;
BEGIN
  full_index_name = 'idx_' || t_name || '_' || i_name;;
  schema_name = 'public';;
  unqValue = '';;
  IF unq THEN
    unqValue = 'UNIQUE ';;
  END IF;;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = full_index_name
    AND n.nspname = schema_name
  ) THEN
    execute 'CREATE ' || unqValue || 'INDEX ' || full_index_name || ' ON ' || schema_name || '.' || t_name || ' ' || index_sql;;
  END IF;;
END
$$
LANGUAGE plpgsql VOLATILE;;

-- Function that is used by a trigger to updated the modified column in the table
CREATE OR REPLACE FUNCTION update_modified() RETURNS TRIGGER AS $$
BEGIN
  NEW.modified = NOW();;
  RETURN NEW;;
END
$$
LANGUAGE plpgsql VOLATILE;;

-- Function to add a user to a project
CREATE OR REPLACE FUNCTION add_user_to_project(projectId integer, userId integer) RETURNS void AS $$
BEGIN
END
$$
LANGUAGE plpgsql VOLATILE;;

-- Map Roulette uses postgis extension for all it's geometries
CREATE EXTENSION IF NOT EXISTS postgis;
-- Map Roulette uses hstore for the properties of all it's geometries
CREATE EXTENSION IF NOT EXISTS HSTORE;

-- The user table contains all users that have logged into Map Roulette.
CREATE TABLE IF NOT EXISTS users
(
  id serial NOT NULL,
  osm_id integer NOT NULL UNIQUE,
  created timestamp without time zone DEFAULT NOW(),
  modified timestamp without time zone DEFAULT NOW(),
  osm_created timestamp without time zone NOT NULL,
  name character varying NOT NULL,
  description character varying,
  avatar_url character varying,
  api_key character varying UNIQUE,
  oauth_token character varying NOT NULL,
  oauth_secret character varying NOT NULL,
  theme character varying DEFAULT('skin-blue'),
  CONSTRAINT users_pkey PRIMARY KEY(id)
);

SELECT AddGeometryColumn('users', 'home_location', 4326, 'POINT', 2);

DROP TRIGGER IF EXISTS update_users_modified ON users;
CREATE TRIGGER update_users_modified BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE PROCEDURE update_modified();

-- Top level object that contains all challenges and surveys
CREATE TABLE IF NOT EXISTS projects
(
  id SERIAL NOT NULL,
  created timestamp without time zone DEFAULT NOW(),
  modified timestamp without time zone DEFAULT NOW(),
  name character varying NOT NULL UNIQUE,
  description character varying DEFAULT '',
  enabled BOOLEAN DEFAULT(true),
  CONSTRAINT projects_pkey PRIMARY KEY (id)
);

DROP TRIGGER IF EXISTS update_projects_modified ON projects;
CREATE TRIGGER update_projects_modified BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE PROCEDURE update_modified();

-- Groups for user role management
CREATE TABLE IF NOT EXISTS groups
(
  id serial NOT NULL,
  project_id integer NOT NULL,
  name character varying NOT NULL UNIQUE,
  group_type integer NOT NULL,
  CONSTRAINT groups_project_id_fkey FOREIGN KEY (project_id)
    REFERENCES projects(id) MATCH SIMPLE
    ON UPDATE CASCADE ON DELETE CASCADE
    DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT groups_pkey PRIMARY KEY(id)
);

-- Table to map users to groups
CREATE TABLE IF NOT EXISTS user_groups
(
  id serial NOT NULL,
  osm_user_id integer NOT NULL,
  group_id integer NOT NULL,
  CONSTRAINT ug_user_id_fkey FOREIGN KEY (osm_user_id)
    REFERENCES users(osm_id) MATCH SIMPLE
    ON UPDATE CASCADE ON DELETE CASCADE
    DEFERRABLE,
  CONSTRAINT ug_group_id_fkey FOREIGN KEY (group_id)
    REFERENCES groups(id) MATCH SIMPLE
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT ug_pkey PRIMARY KEY(id)
);

-- Table for all challenges, which is a child of Project, Surveys are also stored in this table
CREATE TABLE IF NOT EXISTS challenges
(
  id SERIAL NOT NULL,
  created timestamp without time zone DEFAULT NOW(),
  modified timestamp without time zone DEFAULT NOW(),
  identifier character varying DEFAULT '',
  name character varying NOT NULL,
  parent_id integer NOT NULL,
  description character varying DEFAULT '',
  blurb character varying DEFAULT '',
  instruction character varying DEFAULT '',
  difficulty integer DEFAULT 1,
  enabled BOOLEAN DEFAULT(true),
  challenge_type integer NOT NULL DEFAULT(1),
  CONSTRAINT challenges_parent_id_fkey FOREIGN KEY (parent_id)
    REFERENCES projects(id) MATCH SIMPLE
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT challenges_pkey PRIMARY KEY (id)
);

DROP TRIGGER IF EXISTS update_challenges_modified ON challenges;
CREATE TRIGGER update_challenges_modified BEFORE UPDATE ON challenges
  FOR EACH ROW EXECUTE PROCEDURE update_modified();

SELECT create_index_if_not_exists('challenges', 'parent_id', '(parent_id)');
SELECT create_index_if_not_exists('challenges', 'parent_id_name', '(parent_id, name)', true);
SELECT create_index_if_not_exists('challenges', 'identifier', '(identifier)');

-- All the answers for a specific survey
CREATE TABLE IF NOT EXISTS answers
(
  id SERIAL NOT NULL,
  created timestamp without time zone DEFAULT NOW(),
  modified timestamp without time zone DEFAULT NOW(),
  survey_id integer NOT NULL,
  answer character varying NOT NULL,
  CONSTRAINT answers_survey_id_fkey FOREIGN KEY (survey_id)
    REFERENCES challenges(id) MATCH SIMPLE
    ON UPDATE CASCADE ON DELETE CASCADE
    DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT answers_pkey PRIMARY KEY(id)
);

DROP TRIGGER IF EXISTS update_answers_modified ON answers;
CREATE TRIGGER update_answers_modified BEFORE UPDATE ON answers
  FOR EACH ROW EXECUTE PROCEDURE update_modified();

SELECT create_index_if_not_exists('answers', 'survey_id', '(survey_id)');

-- All the tasks for a specific challenge or survey
CREATE TABLE IF NOT EXISTS tasks
(
  id SERIAL NOT NULL,
  created timestamp without time zone DEFAULT NOW(),
  modified timestamp without time zone DEFAULT NOW(),
  identifier character varying DEFAULT '',
  name character varying NOT NULL,
  instruction character varying NOT NULL,
  parent_id integer NOT NULL,
  status integer DEFAULT 0 NOT NULL,
  CONSTRAINT tasks_pkey PRIMARY KEY(id),
  CONSTRAINT tasks_parent_id_fkey FOREIGN KEY (parent_id)
    REFERENCES challenges(id) MATCH SIMPLE
    ON UPDATE CASCADE ON DELETE CASCADE
);

DROP TRIGGER IF EXISTS update_tasks_modified ON tasks;
CREATE TRIGGER update_tasks_modified BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE PROCEDURE update_modified();

SELECT AddGeometryColumn('tasks', 'location', 4326, 'POINT', 2);
SELECT create_index_if_not_exists('tasks', 'parent_id', '(parent_id)');
SELECT create_index_if_not_exists('tasks', 'parent_id_name', '(parent_id, name)', true);

-- The answers for a survey from a user
CREATE TABLE IF NOT EXISTS survey_answers
(
  id SERIAL NOT NULL,
  created timestamp without time zone DEFAULT NOW(),
  user_id integer NOT NULL DEFAULT(-999),
  survey_id integer NOT NULL,
  task_id integer NOT NULL,
  answer_id integer NOT NULL,
  CONSTRAINT survey_answers_user_id_fkey FOREIGN KEY (user_id)
    REFERENCES users(id) MATCH SIMPLE,
  CONSTRAINT survey_answers_survey_id_fkey FOREIGN KEY (survey_id)
    REFERENCES challenges(id) MATCH SIMPLE,
  CONSTRAINT survey_answers_task_id_fkey FOREIGN KEY (task_id)
    REFERENCES tasks(id) MATCH SIMPLE,
  CONSTRAINT survey_answers_answer_id_fkey FOREIGN KEY (answer_id)
    REFERENCES answers(id) MATCH SIMPLE,
  CONSTRAINT survey_answers_pkey PRIMARY KEY(id)
);

SELECT create_index_if_not_exists('survey_answers', 'survey_id', '(survey_id)');

-- The tags that can be applied to a task
CREATE TABLE IF NOT EXISTS tags
(
  id SERIAL NOT NULL,
  created timestamp without time zone DEFAULT NOW(),
  name character varying NOT NULL UNIQUE,
  description character varying DEFAULT '',
  CONSTRAINT tag_pkey PRIMARY KEY(id)
);
-- index has the potentially to slow down inserts badly
SELECT create_index_if_not_exists('tags', 'name', '(name)');

-- The tags associated with a task
CREATE TABLE IF NOT EXISTS tags_on_tasks
(
  id SERIAL NOT NULL,
  task_id integer NOT NULL,
  tag_id integer NOT NULL,
  CONSTRAINT tags_on_tasks_pkey PRIMARY KEY(id),
  CONSTRAINT task_tags_on_tasks_task_id_fkey FOREIGN KEY (task_id)
    REFERENCES tasks (id) MATCH SIMPLE
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT task_tags_on_tasks_tag_id_fkey FOREIGN KEY (tag_id)
    REFERENCES tags (id) MATCH SIMPLE
);

SELECT create_index_if_not_exists('tags_on_tasks', 'task_id', '(task_id)');
SELECT create_index_if_not_exists('tags_on_tasks', 'tag_id', '(tag_id)');
-- This index could slow down inserts pretty badly
SELECT create_index_if_not_exists('tags_on_tasks', 'task_id_tag_id', '(task_id, tag_id)');

-- Geometries for a specific task
CREATE TABLE IF NOT EXISTS task_geometries
(
  id SERIAL NOT NULL,
  task_id integer NOT NULL,
  properties HSTORE,
  CONSTRAINT task_geometries_pkey PRIMARY KEY(id),
  CONSTRAINT task_geometries_task_id_fkey FOREIGN KEY (task_id)
    REFERENCES tasks (id) MATCH SIMPLE
    ON UPDATE CASCADE ON DELETE CASCADE
    DEFERRABLE INITIALLY DEFERRED
);

SELECT AddGeometryColumn('task_geometries', 'geom', 4326, 'GEOMETRY', 2);
SELECT create_index_if_not_exists('task_geometries', 'geom', '(geom)');

-- Actions that are taken in the system, like set the status of a task to 'fixed'
CREATE TABLE IF NOT EXISTS actions
(
  id serial NOT NULL,
  created timestamp without time zone DEFAULT NOW(),
  user_id integer DEFAULT(-999),
  type_id integer,
  item_id integer,
  action integer NOT NULL,
  status integer NOT NULL,
  extra character varying,
  CONSTRAINT actions_user_id_fkey FOREIGN KEY (user_id)
    REFERENCES users(id) MATCH SIMPLE,
  CONSTRAINT actions_pkey PRIMARY KEY (id)
);

SELECT create_index_if_not_exists('actions', 'status', '(status)');
SELECT create_index_if_not_exists('actions', 'item_id', '(item_id)');
SELECT create_index_if_not_exists('actions', 'user_id', '(user_id)');
select create_index_if_not_exists('actions', 'created', '(created)');

-- Insert the default root, used for migration and those using the old API
INSERT INTO projects (id, name, description) VALUES (0, 'SuperRootProject', 'Root Project for super users.');
INSERT INTO groups(id, project_id, name, group_type)  VALUES (-999, 0, 'SUPERUSERS', -1);
INSERT INTO users(id, osm_id, osm_created, name, oauth_token, oauth_secret, theme)
    VALUES (-999, -999, NOW(), 'SuperUser', '', '', 'skin-black');
INSERT INTO user_groups (osm_user_id, group_id) VALUES (-999, -999);

# --- !Downs