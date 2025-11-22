-- Seed data for nsready registry
DO $$
DECLARE
  customer_idx INTEGER;
  customer_name TEXT;
  customer_slug TEXT;
  customer_uuid UUID;
  project_name TEXT;
  project_uuid UUID;
  site_name_value TEXT;
  site_uuid UUID;
  device_number INTEGER;
  device_code_value TEXT;
  device_uuid UUID;
  template_name TEXT;
  template_uuid UUID;
  template_unit TEXT;
  template_dtype TEXT;
  template_min REAL;
  template_max REAL;
  template_required BOOL;
  parameter_templates_has_project BOOLEAN;
  template_key TEXT;
  template_metadata JSONB;
  template_display_name TEXT;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'parameter_templates'
      AND column_name = 'project_id'
  ) INTO parameter_templates_has_project;

  FOR customer_idx IN 1..10 LOOP
    customer_name := format('Customer %s', lpad(customer_idx::text, 2, '0'));
    customer_slug := replace(customer_name, ' ', '_');

    SELECT id INTO customer_uuid FROM customers WHERE name = customer_name;
    IF NOT FOUND THEN
      INSERT INTO customers (id, name)
      VALUES (gen_random_uuid(), customer_name)
      RETURNING id INTO customer_uuid;
    END IF;

    project_name := format('Project 01_%s', customer_slug);
    SELECT id INTO project_uuid FROM projects
    WHERE name = project_name AND customer_id = customer_uuid;
    IF NOT FOUND THEN
      INSERT INTO projects (id, customer_id, name)
      VALUES (gen_random_uuid(), customer_uuid, project_name)
      RETURNING id INTO project_uuid;
    END IF;

    site_name_value := format('Site 01_%s', customer_slug);
    SELECT id INTO site_uuid FROM sites
    WHERE name = site_name_value AND project_id = project_uuid;
    IF NOT FOUND THEN
      INSERT INTO sites (id, project_id, name)
      VALUES (gen_random_uuid(), project_uuid, site_name_value)
      RETURNING id INTO site_uuid;
    END IF;

    FOR device_number IN 1..2 LOOP
      device_code_value := format('DEV_%s_%s', customer_slug, device_number);
      SELECT id INTO device_uuid FROM devices
      WHERE external_id = device_code_value;
      IF NOT FOUND THEN
        INSERT INTO devices (id, site_id, name, device_type, external_id, status)
        VALUES (
          gen_random_uuid(),
          site_uuid,
          device_code_value,
          'sensor',
          device_code_value,
          'active'
        );
      END IF;
    END LOOP;

    IF customer_idx = 1 THEN
      FOREACH template_name IN ARRAY ARRAY['voltage', 'current', 'power'] LOOP
        template_key := format('project:%s:%s', project_uuid::text, template_name);

        IF parameter_templates_has_project THEN
          SELECT id INTO template_uuid FROM parameter_templates
          WHERE project_id = project_uuid AND name = template_name;
        ELSE
          SELECT id INTO template_uuid FROM parameter_templates
          WHERE key = template_key;
        END IF;

        IF NOT FOUND THEN
          CASE template_name
            WHEN 'voltage' THEN
              template_unit := 'V';
              template_dtype := 'float';
              template_min := 0;
              template_max := 240;
              template_required := TRUE;
            WHEN 'current' THEN
              template_unit := 'A';
              template_dtype := 'float';
              template_min := 0;
              template_max := 50;
              template_required := TRUE;
            WHEN 'power' THEN
              template_unit := 'kW';
              template_dtype := 'float';
              template_min := 0;
              template_max := 100;
              template_required := FALSE;
          END CASE;

          IF parameter_templates_has_project THEN
            INSERT INTO parameter_templates (id, project_id, name, unit, dtype, min, max, required)
            VALUES (
              gen_random_uuid(),
              project_uuid,
              template_name,
              template_unit,
              template_dtype,
              template_min,
              template_max,
              template_required
            );
          ELSE
            template_display_name := initcap(template_name);
            template_metadata := jsonb_build_object(
              'project_id', project_uuid::text,
              'dtype', template_dtype,
              'min', template_min,
              'max', template_max,
              'required', template_required
            );

            INSERT INTO parameter_templates (id, key, name, unit, metadata)
            VALUES (
              gen_random_uuid(),
              template_key,
              template_display_name,
              template_unit,
              template_metadata
            );
          END IF;
        END IF;
      END LOOP;
    END IF;
  END LOOP;
END;
$$;
