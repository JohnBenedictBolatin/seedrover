# SeedRover Documentation

Use this index to find current implementation and deployment references. The architecture and product specifications describe design intent; verify details against the implemented app and backend when they differ.

## Getting started

- [Project overview, setup, and verification](../README.md)
- [Web admin setup](../web-admin/README.md)
- [Web admin deployment](web-admin-vercel-deployment.md)
- [Web admin staging checklist](web-admin-staging-checklist.md)

## Architecture and product behavior

- [Application architecture](architecture.md)
- [Feature specification](feature-specification.md)
- [Screen specification](screen-specification.md)
- [UI specification](ui-specification.md)
- [Developer conventions](developer-specification.md)
- [Shared workflow parity](shared-workflow-parity.md)
- [Authentication and session policy](auth-session-policy.md)
- [Activity log](activity-log.md)

## Backend and data

- [Database schema reference](database-schema.md)
- [Database specification](database-specification.md)
- [Data accuracy audit](data-accuracy-audit.md)
- [Input validation audit](input-validation-audit.md)
- [Inventory spoilage estimates](inventory-spoilage-estimates.md)
- [Crop care and harvest workflow](crop-care-harvest-workflow.md)

Database migrations are maintained in [`supabase/migrations`](../supabase/migrations/). SQL tests are in [`supabase/tests`](../supabase/tests/). Review standalone seed and maintenance scripts before running them against any database.

## Rover and hardware

- [Hardware protocol](hardware-protocol.md)
- [Rover firmware setup](../firmware/esp32_seedrover/README.md)
- [Camera firmware setup](../firmware/esp32_cam/README.md)
- [Crop monitoring function deployment](../supabase/functions/CROP_MONITORING_DEPLOYMENT.md)
- [Push notification deployment](../supabase/functions/PUSH_NOTIFICATIONS_DEPLOYMENT.md)

## Planning status

- [Original development roadmap](roadmap.md)

The roadmap records the project's early phase plan and its status section is historical; it is not a reliable summary of the current implementation. Use the root README and the deployment guides for current setup and release instructions.
