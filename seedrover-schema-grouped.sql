-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

-- @group: Users and Operations
CREATE TABLE public.roles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  role_name text NOT NULL UNIQUE,
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT roles_pkey PRIMARY KEY (id)
);
-- @group: Users and Operations
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  username text NOT NULL UNIQUE,
  email text NOT NULL,
  full_name text NOT NULL,
  role_id uuid NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  profile_image_path text,
  contact_number text,
  first_name text,
  last_name text,
  middle_initial text,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id),
  CONSTRAINT profiles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id)
);
-- @group: Users and Operations
CREATE TABLE public.permissions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  permission_key text NOT NULL UNIQUE,
  module text NOT NULL,
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT permissions_pkey PRIMARY KEY (id)
);
-- @group: Users and Operations
CREATE TABLE public.profile_permissions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL,
  permission_id uuid NOT NULL,
  granted_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT profile_permissions_pkey PRIMARY KEY (id),
  CONSTRAINT profile_permissions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id),
  CONSTRAINT profile_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id),
  CONSTRAINT profile_permissions_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES public.profiles(id)
);
-- @group: Rover and Sensors
CREATE TABLE public.robot_status (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  rover_status text NOT NULL DEFAULT 'Offline'::text CHECK (rover_status = ANY (ARRAY['Online'::text, 'Offline'::text, 'Idle'::text, 'Moving'::text, 'Planting'::text, 'Monitoring'::text, 'Error'::text])),
  wifi_connected boolean NOT NULL DEFAULT false,
  bluetooth_connected boolean NOT NULL DEFAULT false,
  camera_connected boolean NOT NULL DEFAULT false,
  current_activity text NOT NULL DEFAULT 'Idle'::text,
  speed integer NOT NULL DEFAULT 0 CHECK (speed >= 0 AND speed <= 100),
  emergency_stop boolean NOT NULL DEFAULT false,
  last_updated timestamp with time zone NOT NULL DEFAULT now(),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT robot_status_pkey PRIMARY KEY (id)
);
-- @group: Rover and Sensors
CREATE TABLE public.sensor_readings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  soil_moisture numeric CHECK (soil_moisture >= 0::numeric AND soil_moisture <= 100::numeric),
  soil_temperature numeric,
  humidity numeric CHECK (humidity >= 0::numeric AND humidity <= 100::numeric),
  environmental_temperature numeric,
  recorded_at timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  rover_id text NOT NULL DEFAULT 'seedrover-01'::text,
  crop_id uuid,
  planting_log_id uuid,
  soil_raw integer,
  calibrated_value numeric CHECK (calibrated_value IS NULL OR calibrated_value >= 0::numeric AND calibrated_value <= 100::numeric),
  calibration_version text,
  source text NOT NULL DEFAULT 'Cloud'::text,
  client_reading_id uuid,
  provenance_status text NOT NULL DEFAULT 'unverified'::text CHECK (provenance_status = ANY (ARRAY['verified_hardware'::text, 'unverified'::text, 'simulated'::text, 'demo'::text])),
  soil_moisture_calibrated boolean,
  firmware_version text,
  CONSTRAINT sensor_readings_pkey PRIMARY KEY (id),
  CONSTRAINT sensor_readings_crop_id_fkey FOREIGN KEY (crop_id) REFERENCES public.crops(id),
  CONSTRAINT sensor_readings_planting_log_id_fkey FOREIGN KEY (planting_log_id) REFERENCES public.planting_logs(id)
);
-- @group: Crop Operations
CREATE TABLE public.planting_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  operator_id uuid NOT NULL,
  crop_name text NOT NULL,
  planting_date date NOT NULL,
  planting_time time without time zone NOT NULL,
  planting_status text NOT NULL CHECK (planting_status = ANY (ARRAY['Pending'::text, 'In Progress'::text, 'Completed'::text, 'Partial'::text, 'Failed'::text, 'Cancelled'::text])),
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  client_session_id uuid,
  rover_id text NOT NULL DEFAULT 'seedrover-01'::text,
  field_label text,
  crop_profile_key text,
  target_drop_cycles integer,
  completed_drop_cycles integer NOT NULL DEFAULT 0,
  measured_distance_cm numeric,
  calculated_area_m2 numeric,
  row_spacing_cm numeric,
  soil_raw integer,
  calibrated_value numeric,
  soil_moisture_percent numeric,
  environmental_temperature numeric,
  firmware_version text,
  started_at timestamp with time zone,
  completed_at timestamp with time zone,
  failure_code text,
  sync_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  distance_is_estimated boolean NOT NULL DEFAULT false,
  movement_tracking text NOT NULL DEFAULT 'unknown'::text CHECK (movement_tracking = ANY (ARRAY['unknown'::text, 'encoder'::text, 'timed_estimate'::text])),
  soil_temperature_c numeric,
  air_temperature_c numeric,
  humidity_percent numeric,
  confirmation_outcome text NOT NULL DEFAULT 'Legacy'::text CHECK (confirmation_outcome = ANY (ARRAY['Legacy'::text, 'Pending'::text, 'Row Planted'::text, 'Some Planted'::text, 'None Planted'::text])),
  confirmed_by uuid,
  confirmed_at timestamp with time zone,
  crop_id uuid,
  soil_captured_at timestamp with time zone,
  CONSTRAINT planting_logs_pkey PRIMARY KEY (id),
  CONSTRAINT planting_logs_operator_id_fkey FOREIGN KEY (operator_id) REFERENCES public.profiles(id),
  CONSTRAINT planting_logs_confirmed_by_fkey FOREIGN KEY (confirmed_by) REFERENCES public.profiles(id),
  CONSTRAINT planting_logs_crop_id_fkey FOREIGN KEY (crop_id) REFERENCES public.crops(id)
);
-- @group: Crop Operations
CREATE TABLE public.crops (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  planting_log_id uuid,
  crop_name text NOT NULL,
  assigned_manager uuid,
  planting_date date NOT NULL,
  estimated_harvest date,
  growth_stage text NOT NULL CHECK (growth_stage = ANY (ARRAY['Seeded'::text, 'Seedbed'::text, 'Germinating'::text, 'Nursery Seedling'::text, 'Transplant Review'::text, 'Establishing'::text, 'Juvenile'::text, 'Vegetative'::text, 'Trellising'::text, 'Flowering'::text, 'Pod Formation'::text, 'Pegging'::text, 'Pod Development'::text, 'Maturity Check'::text, 'First Bearing'::text, 'Fruiting'::text, 'Harvest Ready'::text, 'Repeated Harvest'::text, 'Completed'::text])),
  maintenance_notes text,
  crop_status text NOT NULL CHECK (crop_status = ANY (ARRAY['Active'::text, 'Needs Attention'::text, 'Harvest Ready'::text, 'Completed'::text, 'Cancelled'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  image_path text,
  crop_profile_key text,
  profile_version integer,
  planting_source text NOT NULL DEFAULT 'Legacy'::text CHECK (planting_source = ANY (ARRAY['Rover'::text, 'Manual'::text, 'Legacy'::text])),
  propagation_method text,
  field_label text,
  field_area_m2 numeric,
  completed_drop_cycles integer,
  harvest_window_start date,
  harvest_window_end date,
  forecast_confidence text NOT NULL DEFAULT 'Low'::text CHECK (forecast_confidence = ANY (ARRAY['High'::text, 'Medium'::text, 'Low'::text, 'Unavailable'::text])),
  expected_stage text,
  current_care_status text NOT NULL DEFAULT 'Monitoring'::text,
  last_watered_at timestamp with time zone,
  last_fertilized_at timestamp with time zone,
  manual_creation_reason text,
  transplanted_at timestamp with time zone,
  field_area_is_estimated boolean NOT NULL DEFAULT false,
  batch_code text NOT NULL DEFAULT next_crop_batch_code(),
  harvest_inventory_id uuid,
  harvested_at timestamp with time zone,
  CONSTRAINT crops_pkey PRIMARY KEY (id),
  CONSTRAINT crops_harvest_inventory_id_fkey FOREIGN KEY (harvest_inventory_id) REFERENCES public.inventory(id),
  CONSTRAINT crops_planting_log_id_fkey FOREIGN KEY (planting_log_id) REFERENCES public.planting_logs(id),
  CONSTRAINT crops_assigned_manager_fkey FOREIGN KEY (assigned_manager) REFERENCES public.profiles(id),
  CONSTRAINT crops_crop_profile_key_fkey FOREIGN KEY (crop_profile_key) REFERENCES public.crop_profiles(profile_key)
);
-- @group: Inventory and Sales
CREATE TABLE public.inventory (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  item_name text NOT NULL,
  quantity numeric NOT NULL DEFAULT 0 CHECK (quantity >= 0::numeric),
  unit text NOT NULL CHECK (unit = 'kg'::text),
  minimum_quantity numeric NOT NULL DEFAULT 0 CHECK (minimum_quantity >= 0::numeric),
  storage_location text,
  category text NOT NULL CHECK (category = ANY (ARRAY['Leafy Vegetables'::text, 'Fruit Vegetables'::text, 'Legumes'::text, 'Root Crops'::text, 'Fruits'::text, 'Herbs'::text, 'Prepared Produce'::text, 'Others'::text])),
  updated_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  stock_code text,
  image_path text,
  unit_cost numeric CHECK (unit_cost IS NULL OR unit_cost >= 0::numeric),
  selling_price numeric CHECK (selling_price IS NULL OR selling_price >= 0::numeric),
  notes text,
  CONSTRAINT inventory_pkey PRIMARY KEY (id),
  CONSTRAINT inventory_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.profiles(id)
);
-- @group: Inventory and Sales
CREATE TABLE public.inventory_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  inventory_id uuid NOT NULL,
  transaction_type text NOT NULL CHECK (transaction_type = ANY (ARRAY['IN'::text, 'OUT'::text, 'ADJUSTMENT'::text])),
  quantity numeric NOT NULL CHECK (quantity > 0::numeric),
  remarks text,
  performed_by uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  source text NOT NULL DEFAULT 'manual'::text CHECK (source = ANY (ARRAY['manual'::text, 'sale'::text, 'void_sale'::text, 'harvest'::text])),
  source_id uuid,
  CONSTRAINT inventory_transactions_pkey PRIMARY KEY (id),
  CONSTRAINT inventory_transactions_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES public.inventory(id),
  CONSTRAINT inventory_transactions_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES public.profiles(id)
);
-- @group: Users and Operations
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  recipient_id uuid NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  notification_type text NOT NULL CHECK (notification_type = ANY (ARRAY['Inventory'::text, 'Robot Status'::text, 'Crop Reminder'::text, 'System'::text])),
  is_read boolean NOT NULL DEFAULT false,
  action_route text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  actor_id uuid,
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.profiles(id),
  CONSTRAINT notifications_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(id)
);
-- @group: Users and Operations
CREATE TABLE public.activity_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  activity text NOT NULL,
  description text,
  module text NOT NULL CHECK (module = ANY (ARRAY['Authentication'::text, 'Dashboard'::text, 'Rover'::text, 'Rover Monitor'::text, 'Planting'::text, 'Crops'::text, 'Inventory'::text, 'Stocks'::text, 'Sales'::text, 'Customers'::text, 'Discounts'::text, 'Reports'::text, 'Notifications'::text, 'Profile'::text, 'Users'::text, 'System'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT activity_logs_pkey PRIMARY KEY (id),
  CONSTRAINT activity_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
-- @group: Rover and Sensors
CREATE TABLE public.robot_commands (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  command text NOT NULL CHECK (command = ANY (ARRAY['MOVE_FORWARD'::text, 'MOVE_BACKWARD'::text, 'TURN_LEFT'::text, 'TURN_RIGHT'::text, 'STOP'::text, 'EMERGENCY_STOP'::text, 'START_PLANTING'::text, 'PAUSE_PLANTING'::text, 'RESUME_PLANTING'::text, 'STOP_PLANTING'::text, 'START_CAMERA'::text, 'STOP_CAMERA'::text, 'REFRESH_CAMERA'::text, 'GET_SENSOR_DATA'::text, 'GET_ROBOT_STATUS'::text, 'PING'::text])),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  issued_by uuid NOT NULL,
  status text NOT NULL DEFAULT 'Pending'::text CHECK (status = ANY (ARRAY['Pending'::text, 'Sent'::text, 'Success'::text, 'Failed'::text, 'Invalid Command'::text, 'Busy'::text, 'Disconnected'::text])),
  executed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  rover_id text NOT NULL DEFAULT 'seedrover-01'::text,
  correlation_id uuid NOT NULL DEFAULT gen_random_uuid(),
  expires_at timestamp with time zone,
  acknowledged_at timestamp with time zone,
  failure_details text,
  CONSTRAINT robot_commands_pkey PRIMARY KEY (id),
  CONSTRAINT robot_commands_issued_by_fkey FOREIGN KEY (issued_by) REFERENCES public.profiles(id)
);
-- @group: Inventory and Sales
CREATE TABLE public.sales_transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  inventory_id uuid NOT NULL,
  quantity_sold numeric NOT NULL CHECK (quantity_sold > 0::numeric),
  unit_price numeric NOT NULL CHECK (unit_price >= 0::numeric),
  total_amount numeric NOT NULL CHECK (total_amount >= 0::numeric),
  sale_date timestamp with time zone NOT NULL,
  customer_name text,
  remarks text,
  recorded_by uuid NOT NULL,
  status text NOT NULL DEFAULT 'Completed'::text CHECK (status = ANY (ARRAY['Completed'::text, 'Voided'::text])),
  voided_at timestamp with time zone,
  voided_by uuid,
  void_reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  payment_method text CHECK (payment_method IS NULL OR (payment_method = ANY (ARRAY['Cash'::text, 'GCash'::text, 'Bank Transfer'::text, 'Card'::text, 'Other'::text]))),
  transaction_reference text,
  other_payment_method text,
  customer_id uuid,
  customer_contact text,
  CONSTRAINT sales_transactions_pkey PRIMARY KEY (id),
  CONSTRAINT sales_transactions_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id),
  CONSTRAINT sales_transactions_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES public.inventory(id),
  CONSTRAINT sales_transactions_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES public.profiles(id),
  CONSTRAINT sales_transactions_voided_by_fkey FOREIGN KEY (voided_by) REFERENCES public.profiles(id)
);
-- @group: Inventory and Sales
CREATE TABLE public.sales_orders (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  receipt_number text NOT NULL UNIQUE,
  sale_date timestamp with time zone NOT NULL DEFAULT now(),
  customer_name text,
  customer_contact text,
  payment_method text NOT NULL CHECK (payment_method = ANY (ARRAY['Cash'::text, 'GCash'::text, 'Bank Transfer'::text, 'Card'::text, 'Installment'::text, 'Other'::text])),
  subtotal numeric NOT NULL,
  discount_type text NOT NULL DEFAULT 'None'::text CHECK (discount_type = ANY (ARRAY['None'::text, 'Amount'::text, 'Percent'::text])),
  discount_value numeric NOT NULL DEFAULT 0,
  discount_amount numeric NOT NULL DEFAULT 0,
  total_amount numeric NOT NULL,
  amount_paid numeric,
  change_amount numeric,
  remarks text,
  recorded_by uuid NOT NULL,
  status text NOT NULL DEFAULT 'Completed'::text CHECK (status = ANY (ARRAY['Completed'::text, 'Voided'::text])),
  voided_at timestamp with time zone,
  voided_by uuid,
  void_reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  customer_discount_id uuid,
  discount_code text,
  transaction_reference text,
  other_payment_method text,
  customer_id uuid,
  CONSTRAINT sales_orders_pkey PRIMARY KEY (id),
  CONSTRAINT sales_orders_customer_discount_id_fkey FOREIGN KEY (customer_discount_id) REFERENCES public.customer_discounts(id),
  CONSTRAINT sales_orders_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id),
  CONSTRAINT sales_orders_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES public.profiles(id),
  CONSTRAINT sales_orders_voided_by_fkey FOREIGN KEY (voided_by) REFERENCES public.profiles(id)
);
-- @group: Inventory and Sales
CREATE TABLE public.sales_order_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  sales_order_id uuid NOT NULL,
  inventory_id uuid NOT NULL,
  item_name_snapshot text NOT NULL,
  unit_snapshot text NOT NULL CHECK (unit_snapshot = 'kg'::text),
  quantity_sold numeric NOT NULL CHECK (quantity_sold > 0::numeric),
  unit_price numeric NOT NULL,
  line_total numeric NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT sales_order_items_pkey PRIMARY KEY (id),
  CONSTRAINT sales_order_items_sales_order_id_fkey FOREIGN KEY (sales_order_id) REFERENCES public.sales_orders(id),
  CONSTRAINT sales_order_items_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES public.inventory(id)
);
-- @group: Inventory and Sales
CREATE TABLE public.customers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_key text NOT NULL UNIQUE,
  contact_number text,
  created_by uuid,
  updated_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT customers_pkey PRIMARY KEY (id),
  CONSTRAINT customers_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id),
  CONSTRAINT customers_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.profiles(id)
);
-- @group: Inventory and Sales
CREATE TABLE public.customer_discounts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  discount_code text NOT NULL UNIQUE,
  customer_key text NOT NULL,
  customer_name text NOT NULL,
  customer_contact text,
  discount_type text NOT NULL CHECK (discount_type = ANY (ARRAY['Amount'::text, 'Percent'::text])),
  discount_value numeric NOT NULL CHECK (discount_value > 0::numeric),
  valid_until date,
  notes text,
  status text NOT NULL DEFAULT 'Released'::text CHECK (status = ANY (ARRAY['Released'::text, 'Used'::text, 'Voided'::text])),
  released_by uuid,
  used_by uuid,
  used_sales_order_id uuid,
  released_at timestamp with time zone NOT NULL DEFAULT now(),
  used_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT customer_discounts_pkey PRIMARY KEY (id),
  CONSTRAINT customer_discounts_released_by_fkey FOREIGN KEY (released_by) REFERENCES public.profiles(id),
  CONSTRAINT customer_discounts_used_by_fkey FOREIGN KEY (used_by) REFERENCES public.profiles(id),
  CONSTRAINT customer_discounts_used_sales_order_fk FOREIGN KEY (used_sales_order_id) REFERENCES public.sales_orders(id)
);
-- @group: Users and Operations
CREATE TABLE public.rate_limit_buckets (
  key text NOT NULL,
  count integer NOT NULL DEFAULT 0,
  reset_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT rate_limit_buckets_pkey PRIMARY KEY (key)
);
-- @group: Crop Operations
CREATE TABLE public.crop_harvests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  crop_id uuid NOT NULL,
  inventory_id uuid NOT NULL,
  quantity numeric NOT NULL CHECK (quantity > 0::numeric),
  unit text NOT NULL,
  harvest_date date NOT NULL DEFAULT CURRENT_DATE,
  harvested_by uuid NOT NULL,
  remarks text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  submission_id text,
  CONSTRAINT crop_harvests_pkey PRIMARY KEY (id),
  CONSTRAINT crop_harvests_crop_id_fkey FOREIGN KEY (crop_id) REFERENCES public.crops(id),
  CONSTRAINT crop_harvests_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES public.inventory(id),
  CONSTRAINT crop_harvests_harvested_by_fkey FOREIGN KEY (harvested_by) REFERENCES public.profiles(id)
);
-- @group: Rover and Sensors
CREATE TABLE public.rover_control_leases (
  rover_id text NOT NULL,
  owner_id uuid NOT NULL,
  acquired_at timestamp with time zone NOT NULL DEFAULT now(),
  renewed_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone NOT NULL,
  CONSTRAINT rover_control_leases_pkey PRIMARY KEY (rover_id),
  CONSTRAINT rover_control_leases_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id)
);
-- @group: Finance and Weather
CREATE TABLE public.crop_outcomes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  crop_id uuid,
  crop_name text NOT NULL,
  outcome text NOT NULL DEFAULT 'Failed'::text CHECK (outcome = ANY (ARRAY['Failed'::text, 'Discarded'::text, 'Lost'::text, 'Harvested'::text])),
  reason text,
  quantity numeric,
  recorded_by uuid,
  recorded_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT crop_outcomes_pkey PRIMARY KEY (id),
  CONSTRAINT crop_outcomes_crop_id_fkey FOREIGN KEY (crop_id) REFERENCES public.crops(id),
  CONSTRAINT crop_outcomes_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES public.profiles(id)
);
-- @group: Finance and Weather
CREATE TABLE public.customer_payments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  customer_key text NOT NULL,
  customer_name text NOT NULL,
  sale_reference text,
  amount numeric NOT NULL CHECK (amount > 0::numeric),
  due_date date,
  paid_at timestamp with time zone,
  status text NOT NULL DEFAULT 'Pending'::text CHECK (status = ANY (ARRAY['Pending'::text, 'Paid'::text, 'Overdue'::text])),
  notes text,
  recorded_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT customer_payments_pkey PRIMARY KEY (id),
  CONSTRAINT customer_payments_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES public.profiles(id)
);
-- @group: Finance and Weather
CREATE TABLE public.farm_expenses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  description text NOT NULL,
  category text NOT NULL DEFAULT 'Other'::text,
  amount numeric NOT NULL CHECK (amount > 0::numeric),
  expense_date date NOT NULL DEFAULT CURRENT_DATE,
  notes text,
  recorded_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  vendor text,
  payment_method text NOT NULL DEFAULT 'Cash'::text CHECK (payment_method = ANY (ARRAY['Cash'::text, 'GCash'::text, 'Bank Transfer'::text, 'Card'::text, 'Other'::text])),
  reference_number text,
  expense_type text NOT NULL DEFAULT 'Capital investment'::text CHECK (expense_type = ANY (ARRAY['Capital investment'::text, 'Operating expense'::text])),
  related_crop_id uuid,
  related_inventory_id uuid,
  quantity numeric CHECK (quantity IS NULL OR quantity > 0::numeric),
  unit_cost numeric CHECK (unit_cost IS NULL OR unit_cost >= 0::numeric),
  receipt_path text,
  frequency text CHECK (frequency IS NULL OR (frequency = ANY (ARRAY['Weekly'::text, 'Monthly'::text, 'Quarterly'::text, 'Yearly'::text]))),
  next_due_date date,
  end_date date,
  CONSTRAINT farm_expenses_pkey PRIMARY KEY (id),
  CONSTRAINT farm_expenses_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES public.profiles(id),
  CONSTRAINT farm_expenses_related_crop_id_fkey FOREIGN KEY (related_crop_id) REFERENCES public.crops(id),
  CONSTRAINT farm_expenses_related_inventory_id_fkey FOREIGN KEY (related_inventory_id) REFERENCES public.inventory(id)
);
-- @group: Crop Operations
CREATE TABLE public.crop_profiles (
  profile_key text NOT NULL,
  display_name text NOT NULL,
  scientific_name text,
  version integer NOT NULL DEFAULT 1,
  lifecycle_type text NOT NULL CHECK (lifecycle_type = ANY (ARRAY['Annual'::text, 'Perennial Nursery'::text])),
  propagation_method text NOT NULL,
  row_spacing_cm numeric,
  drop_spacing_cm numeric,
  harvest_start_days integer,
  harvest_end_days integer,
  water_plan jsonb NOT NULL DEFAULT '{}'::jsonb,
  fertilizer_plan jsonb NOT NULL DEFAULT '{}'::jsonb,
  stage_plan jsonb NOT NULL DEFAULT '[]'::jsonb,
  source_title text NOT NULL,
  source_url text NOT NULL,
  source_published_on date,
  advisory text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT crop_profiles_pkey PRIMARY KEY (profile_key)
);
-- @group: Crop Operations
CREATE TABLE public.crop_profile_versions (
  profile_key text NOT NULL,
  version integer NOT NULL,
  profile_snapshot jsonb NOT NULL,
  source_title text NOT NULL,
  source_url text NOT NULL,
  source_published_on date,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT crop_profile_versions_pkey PRIMARY KEY (profile_key, version)
);
-- @group: Crop Operations
CREATE TABLE public.crop_activities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  crop_id uuid NOT NULL,
  activity_type text NOT NULL CHECK (activity_type = ANY (ARRAY['Planted'::text, 'Watered'::text, 'Fertilized'::text, 'Inspected'::text, 'Stage Observed'::text, 'Transplanted'::text, 'Harvested'::text, 'Not Harvested'::text, 'Planting Failed'::text, 'Crop Cycle Finished'::text])),
  performed_at timestamp with time zone NOT NULL DEFAULT now(),
  performed_by uuid,
  quantity numeric CHECK (quantity IS NULL OR quantity >= 0::numeric),
  unit text,
  material text,
  notes text,
  observed_stage text,
  task_id uuid,
  source text NOT NULL DEFAULT 'User'::text CHECK (source = ANY (ARRAY['Rover'::text, 'User'::text, 'System'::text, 'Legacy'::text])),
  idempotency_key text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT crop_activities_pkey PRIMARY KEY (id),
  CONSTRAINT crop_activities_crop_id_fkey FOREIGN KEY (crop_id) REFERENCES public.crops(id),
  CONSTRAINT crop_activities_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES public.profiles(id),
  CONSTRAINT crop_activities_task_id_fkey FOREIGN KEY (task_id) REFERENCES public.crop_tasks(id)
);
-- @group: Crop Operations
CREATE TABLE public.crop_tasks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  crop_id uuid NOT NULL,
  task_type text NOT NULL CHECK (task_type = ANY (ARRAY['Water'::text, 'Fertilize'::text, 'Inspect'::text, 'Transplant'::text, 'Harvest Check'::text, 'Weather Risk'::text])),
  title text NOT NULL,
  recommendation text NOT NULL,
  due_at timestamp with time zone NOT NULL,
  due_window_end timestamp with time zone,
  status text NOT NULL DEFAULT 'Due'::text CHECK (status = ANY (ARRAY['Upcoming'::text, 'Due'::text, 'Overdue'::text, 'Postponed'::text, 'Completed'::text, 'Dismissed'::text])),
  priority text NOT NULL DEFAULT 'Routine'::text CHECK (priority = ANY (ARRAY['Routine'::text, 'Important'::text, 'Critical'::text])),
  recommendation_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  forecast_basis jsonb NOT NULL DEFAULT '{}'::jsonb,
  deduplication_key text NOT NULL UNIQUE,
  completed_at timestamp with time zone,
  completed_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT crop_tasks_pkey PRIMARY KEY (id),
  CONSTRAINT crop_tasks_crop_id_fkey FOREIGN KEY (crop_id) REFERENCES public.crops(id),
  CONSTRAINT crop_tasks_completed_by_fkey FOREIGN KEY (completed_by) REFERENCES public.profiles(id)
);
-- @group: Finance and Weather
CREATE TABLE public.farm_weather_settings (
  id boolean NOT NULL DEFAULT true CHECK (id),
  latitude numeric,
  longitude numeric,
  pagasa_region text,
  pagasa_province text,
  pagasa_municipality text,
  pagasa_psgc text,
  timezone text NOT NULL DEFAULT 'Asia/Manila'::text,
  soil_type text NOT NULL DEFAULT 'Unknown'::text,
  irrigation_method text NOT NULL DEFAULT 'Manual hose or watering can'::text,
  irrigation_efficiency numeric NOT NULL DEFAULT 0.80 CHECK (irrigation_efficiency > 0::numeric AND irrigation_efficiency <= 1::numeric),
  routine_digest_hour integer NOT NULL DEFAULT 6 CHECK (routine_digest_hour >= 0 AND routine_digest_hour <= 23),
  updated_by uuid,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT farm_weather_settings_pkey PRIMARY KEY (id),
  CONSTRAINT farm_weather_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.profiles(id)
);
-- @group: Finance and Weather
CREATE TABLE public.weather_forecasts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  provider text NOT NULL CHECK (provider = ANY (ARRAY['PAGASA'::text, 'Open-Meteo'::text])),
  forecast_for timestamp with time zone NOT NULL,
  issued_at timestamp with time zone,
  precipitation_probability numeric,
  precipitation_mm numeric,
  et0_mm numeric,
  temperature_c numeric,
  humidity_percent numeric,
  condition text,
  location_label text,
  raw_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  fetched_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT weather_forecasts_pkey PRIMARY KEY (id)
);
-- @group: Users and Operations
CREATE TABLE public.push_device_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL,
  token text NOT NULL UNIQUE,
  platform text NOT NULL CHECK (platform = ANY (ARRAY['android'::text, 'ios'::text, 'web'::text])),
  is_active boolean NOT NULL DEFAULT true,
  last_seen_at timestamp with time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT push_device_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT push_device_tokens_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id)
);
-- @group: Rover and Sensors
CREATE TABLE public.rover_calibrations (
  rover_id text NOT NULL,
  left_encoder_ticks_per_meter numeric,
  right_encoder_ticks_per_meter numeric,
  soil_dry_raw integer,
  soil_wet_raw integer,
  rake_to_gate_offset_cm numeric NOT NULL DEFAULT 18,
  seed_gate_profiles jsonb NOT NULL DEFAULT '{"sitaw": {"gate_open_ms": 120, "estimated_max": 3, "estimated_min": 2}, "peanut": {"gate_open_ms": 120, "estimated_max": 2, "estimated_min": 1}, "calamansi": {"gate_open_ms": 120, "estimated_max": 3, "estimated_min": 1}}'::jsonb,
  calibrated_by uuid,
  calibrated_at timestamp with time zone,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  seconds_per_meter numeric CHECK (seconds_per_meter IS NULL OR seconds_per_meter > 0::numeric AND seconds_per_meter <= 120::numeric),
  CONSTRAINT rover_calibrations_pkey PRIMARY KEY (rover_id),
  CONSTRAINT rover_calibrations_calibrated_by_fkey FOREIGN KEY (calibrated_by) REFERENCES public.profiles(id)
);
-- @group: Finance and Weather
CREATE TABLE public.installment_plans (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  sales_order_id uuid NOT NULL UNIQUE,
  customer_name text NOT NULL,
  customer_contact text,
  receipt_number text NOT NULL,
  frequency text NOT NULL CHECK (frequency = ANY (ARRAY['Weekly'::text, 'Monthly'::text, 'Yearly'::text])),
  payment_amount numeric NOT NULL,
  total_amount numeric NOT NULL,
  initial_payment numeric NOT NULL DEFAULT 0,
  financed_amount numeric NOT NULL,
  status text NOT NULL DEFAULT 'Active'::text CHECK (status = ANY (ARRAY['Active'::text, 'Completed'::text, 'Cancelled'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT installment_plans_pkey PRIMARY KEY (id),
  CONSTRAINT installment_plans_sales_order_id_fkey FOREIGN KEY (sales_order_id) REFERENCES public.sales_orders(id)
);
-- @group: Finance and Weather
CREATE TABLE public.installment_schedule (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL,
  installment_number integer NOT NULL CHECK (installment_number > 0),
  due_date date NOT NULL,
  scheduled_amount numeric NOT NULL CHECK (scheduled_amount > 0::numeric),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT installment_schedule_pkey PRIMARY KEY (id),
  CONSTRAINT installment_schedule_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.installment_plans(id)
);
-- @group: Finance and Weather
CREATE TABLE public.installment_payments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL,
  schedule_id uuid NOT NULL,
  amount numeric NOT NULL CHECK (amount > 0::numeric),
  payment_date date NOT NULL DEFAULT CURRENT_DATE,
  payment_method text NOT NULL CHECK (payment_method = ANY (ARRAY['Cash'::text, 'GCash'::text, 'Bank Transfer'::text, 'Card'::text, 'Other'::text])),
  transaction_reference text,
  other_payment_method text,
  notes text,
  recorded_by uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  receipt_path text,
  collection_group_id uuid NOT NULL DEFAULT gen_random_uuid(),
  collection_type text NOT NULL DEFAULT 'installment'::text CHECK (collection_type = ANY (ARRAY['down_payment'::text, 'installment'::text])),
  CONSTRAINT installment_payments_pkey PRIMARY KEY (id),
  CONSTRAINT installment_payments_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES public.installment_plans(id),
  CONSTRAINT installment_payments_schedule_id_fkey FOREIGN KEY (schedule_id) REFERENCES public.installment_schedule(id),
  CONSTRAINT installment_payments_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES public.profiles(id)
);
-- @group: Crop Operations
CREATE TABLE public.crop_profile_images (
  profile_key text NOT NULL CHECK (profile_key = ANY (ARRAY['sitaw'::text, 'peanut'::text, 'calamansi'::text])),
  image_path text NOT NULL,
  updated_by uuid,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT crop_profile_images_pkey PRIMARY KEY (profile_key),
  CONSTRAINT crop_profile_images_profile_key_fkey FOREIGN KEY (profile_key) REFERENCES public.crop_profiles(profile_key),
  CONSTRAINT crop_profile_images_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.profiles(id)
);
-- @group: Crop Operations
CREATE TABLE public.crop_activity_photos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  activity_id uuid NOT NULL,
  crop_id uuid NOT NULL,
  path text NOT NULL UNIQUE,
  created_by uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT crop_activity_photos_pkey PRIMARY KEY (id),
  CONSTRAINT crop_activity_photos_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES public.crop_activities(id),
  CONSTRAINT crop_activity_photos_crop_id_fkey FOREIGN KEY (crop_id) REFERENCES public.crops(id),
  CONSTRAINT crop_activity_photos_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id)
);
-- @group: Crop Operations
CREATE TABLE public.crop_notification_preferences (
  user_id uuid NOT NULL,
  digest_enabled boolean NOT NULL DEFAULT true,
  digest_hour integer NOT NULL DEFAULT 6 CHECK (digest_hour >= 0 AND digest_hour <= 23),
  quiet_start integer NOT NULL DEFAULT 21 CHECK (quiet_start >= 0 AND quiet_start <= 23),
  quiet_end integer NOT NULL DEFAULT 6 CHECK (quiet_end >= 0 AND quiet_end <= 23),
  CONSTRAINT crop_notification_preferences_pkey PRIMARY KEY (user_id),
  CONSTRAINT crop_notification_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);