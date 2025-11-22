-- Enhance registry_versions to support versioning and publishing metadata
ALTER TABLE registry_versions
ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS version INTEGER,
ADD COLUMN IF NOT EXISTS diff_json JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS author TEXT,
ADD COLUMN IF NOT EXISTS full_config JSONB DEFAULT '{}'::jsonb;

CREATE UNIQUE INDEX IF NOT EXISTS uq_registry_versions_project_version
  ON registry_versions(project_id, version)
  WHERE project_id IS NOT NULL AND version IS NOT NULL;


