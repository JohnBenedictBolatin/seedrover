# Crop Image Asset Naming

Crop images can change by crop type, growth stage, or urgent status.

Place transparent PNG files in this folder using this pattern:

```text
{crop}_{state}.png
```

Supported crops:

- `calamansi`
- `peanut`
- `sitaw`

Supported growth states:

- `seeded`
- `germinating`
- `vegetative`
- `flowering`
- `fruiting`
- `harvest_ready`
- `harvested`

Supported status override states:

- `needs_water`
- `needs_fertilizer`

Examples:

- `calamansi_seeded.png`
- `calamansi_needs_water.png`
- `peanut_germinating.png`
- `peanut_harvest_ready.png`
- `sitaw_fruiting.png`
- `sitaw_needs_fertilizer.png`

If a matching image is missing, the app shows a state-aware placeholder.
