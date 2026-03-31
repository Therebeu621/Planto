-- Keep the application schema and SonarQube schema isolated in local dev.
-- This script only runs on first initialization of the Postgres volume.
CREATE DATABASE sonarqube;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO plant_user;
