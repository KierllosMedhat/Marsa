-- PostgreSQL initialization script
-- Run once when the Docker container first starts.
-- The marsa_dev database is created by the POSTGRES_DB env var.
-- This script creates the clinical schema with restricted grants.

-- Create the clinical schema (sensitive data lives here)
CREATE SCHEMA IF NOT EXISTS clinical;

-- Create a restricted role for the receptionist DB user
-- (the application uses a single DB user but enforces roles in code;
--  this provides a defense-in-depth layer for direct DB access)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'marsa_receptionist') THEN
    CREATE ROLE marsa_receptionist NOLOGIN;
  END IF;
END
$$;

-- Grant access to public schema tables (non-clinical)
GRANT USAGE ON SCHEMA public TO marsa_receptionist;
-- marsa_receptionist has NO access to the clinical schema

-- Enable useful extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";   -- trigram similarity for patient duplicate detection
CREATE EXTENSION IF NOT EXISTS "unaccent";   -- accent-insensitive search
