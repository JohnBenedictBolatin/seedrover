import { createClient } from "npm:@supabase/supabase-js@2";

type Json = Record<string, unknown>;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-cron-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (request.method !== "POST") return reply({ error: "Method not allowed." }, 405);

  const cronSecret = Deno.env.get("CROP_MONITOR_CRON_SECRET") ?? "";
  const suppliedSecret = request.headers.get("x-cron-secret") ?? "";
  const authorization = request.headers.get("authorization") ?? "";
  const supabaseUrl = required("SUPABASE_URL");
  const serviceKey = required("SUPABASE_SERVICE_ROLE_KEY");
  const cronAuthorized = Boolean(cronSecret) && suppliedSecret === cronSecret;
  const serviceAuthorized = authorization === `Bearer ${serviceKey}`;
  if (!cronAuthorized && !serviceAuthorized) {
    const caller = createClient(supabaseUrl, required("SUPABASE_ANON_KEY"), {
      global: { headers: { Authorization: authorization } },
    });
    const [{ data: userData }, { data: canManage }] = await Promise.all([
      caller.auth.getUser(),
      caller.rpc("has_permission", { requested_permission: "crops.manage" }),
    ]);
    if (!userData.user || canManage !== true) {
      return reply({ error: "Crop management permission required." }, 403);
    }
  }

  const admin = createClient(supabaseUrl, serviceKey);
  const now = new Date();

  try {
    const { data: settings, error: settingsError } = await admin
      .from("farm_weather_settings")
      .select("*")
      .eq("id", true)
      .maybeSingle();
    if (settingsError) throw settingsError;

    const weather = await loadWeather(admin, settings, now);
    const { data: crops, error: cropError } = await admin
      .from("crops")
      .select("id,crop_name,assigned_manager,planting_date,crop_profile_key,field_area_m2,harvest_window_start,harvest_window_end,last_watered_at,last_fertilized_at,growth_stage,crop_status,crop_profiles(*)")
      .in("crop_status", ["Active", "Needs Attention", "Harvest Ready"]);
    if (cropError) throw cropError;

    const results = [];
    for (const crop of crops ?? []) {
      results.push(await evaluateCrop(admin, crop as Json, settings as Json | null, weather, now));
    }
    await sendRoutineDigest(admin, now);

    return reply({ status: "success", weather, crops: results.length, results });
  } catch (error) {
    console.error("crop-monitor failed", error);
    return reply({ error: error instanceof Error ? error.message : "Crop monitoring failed." }, 500);
  }
});

async function loadWeather(
  admin: ReturnType<typeof createClient>,
  settings: Json | null,
  now: Date,
) {
  const latitude = number(settings?.latitude);
  const longitude = number(settings?.longitude);
  let openMeteo = null;
  if (latitude !== null && longitude !== null) {
    try {
      openMeteo = await loadOpenMeteo(admin, latitude, longitude, now);
    } catch (error) {
      console.warn("Open-Meteo unavailable; continuing with PAGASA if configured", error);
    }
  }
  const pagasa = await loadPagasa(admin, settings, now);

  const openRain = (openMeteo?.precipitationMm ?? 0) >= 2 || (openMeteo?.precipitationProbability ?? 0) >= 60;
  const pagasaRain = pagasa?.rainExpected ?? null;
  const uncertain = pagasaRain !== null && pagasaRain !== openRain;
  return {
    openMeteo,
    pagasa,
    uncertain,
    rainExpected: pagasaRain ?? openRain,
    providerStatus: pagasa && openMeteo ? "Hybrid" : pagasa ? "PAGASA" : openMeteo ? "Open-Meteo fallback" : "Unavailable",
  };
}

async function loadOpenMeteo(
  admin: ReturnType<typeof createClient>,
  latitude: number,
  longitude: number,
  now: Date,
) {
  const url = new URL("https://api.open-meteo.com/v1/forecast");
  url.searchParams.set("latitude", String(latitude));
  url.searchParams.set("longitude", String(longitude));
  url.searchParams.set("hourly", "temperature_2m,relative_humidity_2m,precipitation_probability,precipitation,et0_fao_evapotranspiration");
  url.searchParams.set("current", "temperature_2m,relative_humidity_2m,precipitation,weather_code");
  url.searchParams.set("forecast_days", "2");
  url.searchParams.set("timezone", "Asia/Manila");
  url.searchParams.set("timeformat", "unixtime");
  const response = await fetch(url, { signal: AbortSignal.timeout(9000) });
  if (!response.ok) throw new Error(`Open-Meteo returned ${response.status}.`);
  const payload = await response.json() as Json;
  const hourly = payload.hourly as Json | undefined;
  const current = payload.current as Json | undefined;
  const times = numberArray(hourly?.time);
  const cutoff = now.getTime() + 24 * 60 * 60 * 1000;
  const indexes = times.map((time, index) => ({ time: new Date(time * 1000), index }))
    .filter(({ time }) => time.getTime() >= now.getTime() - 60 * 60 * 1000 && time.getTime() <= cutoff);
  const precipitation = numberArray(hourly?.precipitation);
  const probabilities = numberArray(hourly?.precipitation_probability);
  const et0 = numberArray(hourly?.et0_fao_evapotranspiration);
  const temperatures = numberArray(hourly?.temperature_2m);
  const humidity = numberArray(hourly?.relative_humidity_2m);
  const summary = {
    precipitationMm: sum(indexes.map(({ index }) => precipitation[index] ?? 0)),
    precipitationProbability: max(indexes.map(({ index }) => probabilities[index] ?? 0)),
    et0Mm: sum(indexes.map(({ index }) => et0[index] ?? 0)),
    currentCondition: weatherCodeLabel(current?.weather_code),
    currentTemperatureC: number(current?.temperature_2m) ?? average(indexes.map(({ index }) => temperatures[index]).filter(isNumber)),
    currentHumidityPercent: number(current?.relative_humidity_2m) ?? average(indexes.map(({ index }) => humidity[index]).filter(isNumber)),
    currentPrecipitationMm: number(current?.precipitation) ?? 0,
    nextRainAt: indexes.find(({ index }) => (precipitation[index] ?? 0) > 0.1)?.time.toISOString() ?? null,
  };

  await admin.from("weather_forecasts").upsert({
    provider: "Open-Meteo",
    forecast_for: hourStart(now).toISOString(),
    issued_at: now.toISOString(),
    precipitation_probability: summary.precipitationProbability,
    precipitation_mm: summary.precipitationMm,
    et0_mm: summary.et0Mm,
    temperature_c: summary.currentTemperatureC,
    humidity_percent: summary.currentHumidityPercent,
    condition: summary.currentCondition,
    location_label: `${latitude},${longitude}`,
    raw_payload: { summary, generationtime_ms: payload.generationtime_ms },
    fetched_at: now.toISOString(),
  }, { onConflict: "provider,forecast_for" });
  return summary;
}

function weatherCodeLabel(value: unknown) {
  const code = number(value);
  if (code === null) return "Weather unavailable";
  if (code === 0) return "Clear sky";
  if (code === 1) return "Mostly clear";
  if (code === 2) return "Partly cloudy";
  if (code === 3) return "Cloudy";
  if (code === 45 || code === 48) return "Foggy";
  if (code >= 51 && code <= 57) return "Drizzle";
  if (code >= 61 && code <= 67) return "Rain";
  if (code >= 71 && code <= 77) return "Snow";
  if (code >= 80 && code <= 82) return "Rain showers";
  if (code >= 85 && code <= 86) return "Snow showers";
  if (code >= 95) return "Thunderstorms";
  return "Weather unavailable";
}

async function loadPagasa(
  admin: ReturnType<typeof createClient>,
  settings: Json | null,
  now: Date,
) {
  const token = Deno.env.get("PAGASA_TENDAY_TOKEN") ?? "";
  const municipality = String(settings?.pagasa_municipality ?? "").trim();
  const province = String(settings?.pagasa_province ?? "").trim();
  if (!token || (!municipality && !province)) return null;

  try {
    const url = new URL("https://tenday.pagasa.dost.gov.ph/api/v1/tenday/full");
    url.searchParams.set("token", token);
    if (municipality) url.searchParams.set("municity", municipality);
    else url.searchParams.set("province", province);
    url.searchParams.set("page", "none");
    const response = await fetch(url, { signal: AbortSignal.timeout(9000) });
    if (!response.ok) throw new Error(`PAGASA returned ${response.status}.`);
    const payload = await response.json() as Json;
    const text = JSON.stringify(payload).toLowerCase();
    const rainExpected = /(light|moderate|heavy|intense|torrential) rain|rainfall/.test(text) && !/no rain/.test(text);
    const heavyRain = /(heavy|intense|torrential) rain/.test(text);
    const summary = { rainExpected, heavyRain, municipality: municipality || null, province: province || null };
    await admin.from("weather_forecasts").upsert({
      provider: "PAGASA",
      forecast_for: hourStart(now).toISOString(),
      issued_at: now.toISOString(),
      condition: heavyRain ? "Heavy rain forecast" : rainExpected ? "Rain forecast" : "No significant rain",
      location_label: municipality || province,
      raw_payload: payload,
      fetched_at: now.toISOString(),
    }, { onConflict: "provider,forecast_for" });
    return summary;
  } catch (error) {
    console.warn("PAGASA unavailable; using Open-Meteo fallback", error);
    return null;
  }
}

async function evaluateCrop(
  admin: ReturnType<typeof createClient>,
  crop: Json,
  settings: Json | null,
  weather: Awaited<ReturnType<typeof loadWeather>>,
  now: Date,
) {
  const profile = relation(crop.crop_profiles);
  if (!profile) return { cropId: crop.id, skipped: "Missing crop profile" };
  const cropId = String(crop.id);
  const cropName = String(crop.crop_name ?? profile.display_name ?? "Crop");
  const plantingDate = new Date(String(crop.planting_date));
  const ageDays = Math.max(0, Math.floor((now.getTime() - plantingDate.getTime()) / 86_400_000));
  const stage = expectedStage(profile.stage_plan, ageDays, String(crop.growth_stage ?? "Seeded"));
  const waterPlan = relation(profile.water_plan) ?? {};
  const coefficients = relation(waterPlan.crop_coefficients) ?? {};
  const kc = coefficientForStage(coefficients, stage, String(profile.profile_key));
  const et0 = weather.openMeteo?.et0Mm ?? 0;
  const rain = weather.openMeteo?.precipitationMm ?? 0;
  const area = number(crop.field_area_m2) ?? 0;
  const efficiency = number(settings?.irrigation_efficiency) ?? 0.8;
  const { data: recentWatering } = await admin.from("crop_activities")
    .select("quantity,unit,performed_at").eq("crop_id", cropId).eq("activity_type", "Watered")
    .gte("performed_at", new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString());
  const recordedLiters = (recentWatering ?? []).reduce((total, activity) => {
    const unit = String(activity.unit ?? "").toLowerCase();
    return total + (unit.startsWith("l") ? number(activity.quantity) ?? 0 : 0);
  }, 0);
  const recordedWaterMm = area > 0 ? recordedLiters * efficiency / area : 0;
  const deficitMm = Math.max(0, round(et0 * kc - rain * 0.8 - recordedWaterMm, 2));
  const liters = area > 0 ? round(deficitMm * area / efficiency, 1) : null;
  const hoursSinceWatered = crop.last_watered_at
    ? (now.getTime() - new Date(String(crop.last_watered_at)).getTime()) / 3_600_000
    : (now.getTime() - plantingDate.getTime()) / 3_600_000;
  const criticalStage = stringArray(waterPlan.critical_stages).some((item) => normalize(item) === normalize(stage));
  const waterDue = hoursSinceWatered >= (criticalStage ? 24 : 48) || deficitMm >= 3;
  const tasks = [];
  const { data: latestSensor } = await admin.from("sensor_readings")
    .select("calibrated_value,soil_moisture,recorded_at")
    .eq("crop_id", cropId).order("recorded_at", { ascending: false }).limit(1).maybeSingle();
  const soilPercent = number(latestSensor?.calibrated_value ?? latestSensor?.soil_moisture);

  if (soilPercent !== null && (soilPercent <= 15 || soilPercent >= 95)) {
    const criticallyDry = soilPercent <= 15;
    tasks.push(await upsertTask(admin, crop, {
      taskType: "Weather Risk",
      title: criticallyDry ? `Critical dry-soil check for ${cropName}` : `Flooding or saturation check for ${cropName}`,
      recommendation: criticallyDry
        ? `The calibrated sensor reported ${soilPercent}%. Inspect the field immediately before applying the calculated water estimate.`
        : `The calibrated sensor reported ${soilPercent}%. Inspect drainage and standing water immediately.`,
      dueAt: now,
      status: "Due",
      priority: "Critical",
      data: { soil_moisture_percent: soilPercent, sensor_recorded_at: latestSensor?.recorded_at, field_confirmation_required: true },
      forecast: weather,
      key: `crop:${cropId}:critical-soil:${criticallyDry ? "dry" : "wet"}:${dateKey(now)}`,
    }));
  }
  const heavyRainRisk = weather.pagasa?.heavyRain === true || (weather.openMeteo?.precipitationMm ?? 0) >= 25;
  if (heavyRainRisk) {
    tasks.push(await upsertTask(admin, crop, {
      taskType: "Weather Risk",
      title: `Heavy-rain field check for ${cropName}`,
      recommendation: "Inspect drainage, erosion, and standing water. Delay fertilizer and do not mark watering complete from forecast rain.",
      dueAt: now,
      status: "Due",
      priority: "Critical",
      data: { precipitation_mm: weather.openMeteo?.precipitationMm ?? null, pagasa_heavy_rain: weather.pagasa?.heavyRain ?? false },
      forecast: weather,
      key: `crop:${cropId}:heavy-rain:${dateKey(now)}`,
    }));
  }

  if (waterDue) {
    const postponed = weather.rainExpected && !weather.uncertain && deficitMm < 5;
    const advice = postponed
      ? `Rain may cover part of the ${deficitMm} mm estimated deficit. Recheck the soil after rainfall; rain does not count as recorded watering.`
      : weather.uncertain
      ? `Forecasts disagree. Check soil before applying approximately ${formatWater(deficitMm, liters)}.`
      : `Check soil, then apply approximately ${formatWater(deficitMm, liters)} if the field is dry.`;
    tasks.push(await upsertTask(admin, crop, {
      taskType: "Water",
      title: `Check water need for ${cropName}`,
      recommendation: advice,
      dueAt: now,
      status: postponed ? "Postponed" : "Due",
      priority: deficitMm >= 5 ? "Critical" : "Routine",
      data: { deficit_mm: deficitMm, estimated_liters: liters, recorded_watering_liters_24h: recordedLiters, field_area_m2: area, crop_coefficient: kc, field_confirmation_required: true },
      forecast: weather,
      key: `crop:${cropId}:water:${dateKey(now)}`,
    }));
  }

  if (deficitMm >= 5 && hoursSinceWatered >= 72 && crop.harvest_window_start) {
    const delayKey = `crop:${cropId}:care-delay:${dateKey(now)}`;
    const { data: existingDelay } = await admin.from("crop_tasks").select("id").eq("deduplication_key", delayKey).maybeSingle();
    if (!existingDelay) {
      await admin.from("crops").update({
        harvest_window_start: addDays(String(crop.harvest_window_start), 1),
        harvest_window_end: addDays(String(crop.harvest_window_end ?? crop.harvest_window_start), 2),
        forecast_confidence: "Low",
      }).eq("id", cropId);
      tasks.push(await upsertTask(admin, crop, {
        taskType: "Inspect",
        title: `Inspect ${cropName} after sustained water stress`,
        recommendation: "The harvest window was widened and delayed because care was missed during a calculated high water deficit. Confirm crop condition in the field.",
        dueAt: now,
        status: "Due",
        priority: "Important",
        data: { deficit_mm: deficitMm, hours_since_recorded_watering: round(hoursSinceWatered, 1), harvest_delay_days: 1 },
        forecast: weather,
        key: delayKey,
      }));
    }
  }

  const fertilizerEvents = array(relation(profile.fertilizer_plan)?.events ?? relation(profile.fertilizer_plan)?.fallbacks);
  const firstFertilizerDay = String(profile.profile_key) === "calamansi" ? 30 : 0;
  const fertilizerDue = fertilizerEvents.length > 0 && ageDays >= firstFertilizerDay && !crop.last_fertilized_at;
  if (fertilizerDue) {
    const heavyRain = weather.pagasa?.heavyRain === true || (weather.openMeteo?.precipitationMm ?? 0) >= 10;
    tasks.push(await upsertTask(admin, crop, {
      taskType: "Fertilize",
      title: `Review fertilizer for ${cropName}`,
      recommendation: heavyRain
        ? "Heavy rain may wash nutrients away. Postpone application and confirm soil and product-label guidance."
        : "Review the crop-profile amount, soil-test result, and product label before applying fertilizer.",
      dueAt: now,
      status: heavyRain ? "Postponed" : "Due",
      priority: "Routine",
      data: { profile_guidance: fertilizerEvents, soil_test_first: true, field_confirmation_required: true },
      forecast: weather,
      key: `crop:${cropId}:fertilize:${dateKey(now)}`,
    }));
  }

  const harvestStart = crop.harvest_window_start ? new Date(String(crop.harvest_window_start)) : null;
  const harvestEnd = crop.harvest_window_end ? new Date(String(crop.harvest_window_end)) : null;
  if (harvestStart && now.getTime() >= harvestStart.getTime() - 7 * 86_400_000) {
    tasks.push(await upsertTask(admin, crop, {
      taskType: "Harvest Check",
      title: `Inspect ${cropName} for harvest readiness`,
      recommendation: `Expected window: ${dateKey(harvestStart)}${harvestEnd ? ` to ${dateKey(harvestEnd)}` : ""}. Confirm physical maturity before harvesting.`,
      dueAt: harvestStart,
      status: now >= harvestStart ? "Due" : "Upcoming",
      priority: now >= harvestStart ? "Important" : "Routine",
      data: { expected_stage: stage, physical_confirmation_required: true },
      forecast: weather,
      key: `crop:${cropId}:harvest:${dateKey(harvestStart)}`,
    }));
  }

  await admin.from("crops").update({
    expected_stage: stage,
    current_care_status: tasks.some((task) => task?.priority === "Critical") ? "Urgent care check" : tasks.length ? "Care tasks due" : "Monitoring",
    forecast_confidence: deficitMm >= 5 && hoursSinceWatered >= 72 ? "Low" : weather.providerStatus === "Hybrid" && !weather.uncertain ? "High" : weather.providerStatus === "Unavailable" ? "Unavailable" : weather.uncertain ? "Low" : "Medium",
  }).eq("id", cropId);

  return { cropId, expectedStage: stage, tasks: tasks.filter(Boolean).length, deficitMm, liters };
}

async function upsertTask(
  admin: ReturnType<typeof createClient>,
  crop: Json,
  task: {
    taskType: string; title: string; recommendation: string; dueAt: Date;
    status: string; priority: string; data: Json; forecast: unknown; key: string;
  },
) {
  const { data: existing } = await admin.from("crop_tasks").select("id").eq("deduplication_key", task.key).maybeSingle();
  const { data, error } = await admin.from("crop_tasks").upsert({
    crop_id: crop.id,
    task_type: task.taskType,
    title: task.title,
    recommendation: task.recommendation,
    due_at: task.dueAt.toISOString(),
    status: task.status,
    priority: task.priority,
    recommendation_data: task.data,
    forecast_basis: task.forecast,
    deduplication_key: task.key,
  }, { onConflict: "deduplication_key" }).select("id,priority,status").single();
  if (error) throw error;

  const shouldNotify = !existing && task.priority === "Critical";
  if (shouldNotify) await notifyRecipients(admin, crop, task, String(data.id));
  return data;
}

async function notifyRecipients(
  admin: ReturnType<typeof createClient>,
  crop: Json,
  task: { title: string; recommendation: string; priority: string },
  taskId: string,
) {
  const recipients = new Set<string>();
  if (crop.assigned_manager) recipients.add(String(crop.assigned_manager));
  const { data: admins } = await admin.from("profiles").select("id,roles!inner(role_name)").eq("is_active", true).eq("roles.role_name", "System Administrator");
  for (const profile of admins ?? []) recipients.add(String(profile.id));
  if (!recipients.size) return;
  await admin.from("notifications").insert([...recipients].map((recipientId) => ({
    recipient_id: recipientId,
    title: task.priority === "Critical" ? `Urgent: ${task.title}` : task.title,
    message: task.recommendation,
    notification_type: "Crop Reminder",
    action_route: `/crops/${crop.id}?task=${taskId}`,
  })));
}

async function sendRoutineDigest(admin: ReturnType<typeof createClient>, now: Date) {
  const localHour = Number(new Intl.DateTimeFormat("en-US", { timeZone: "Asia/Manila", hour: "2-digit", hour12: false }).format(now));
  if (localHour !== 6) return;
  const localDate = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Manila", year: "numeric", month: "2-digit", day: "2-digit" }).format(now);
  const { data: tasks } = await admin.from("crop_tasks")
    .select("id,crop_id,title,priority,crops!inner(assigned_manager)")
    .in("status", ["Due", "Overdue", "Upcoming"]).lte("due_at", new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString());
  if (!tasks?.length) return;
  const { data: admins } = await admin.from("profiles").select("id,roles!inner(role_name)").eq("is_active", true).eq("roles.role_name", "System Administrator");
  const perRecipient = new Map<string, number>();
  for (const task of tasks) {
    const crop = relation(task.crops);
    if (crop?.assigned_manager) perRecipient.set(String(crop.assigned_manager), (perRecipient.get(String(crop.assigned_manager)) ?? 0) + 1);
  }
  for (const profile of admins ?? []) perRecipient.set(String(profile.id), tasks.length);
  for (const [recipientId, count] of perRecipient) {
    const route = `/crops?digest=${localDate}`;
    const { data: existing } = await admin.from("notifications").select("id").eq("recipient_id", recipientId).eq("title", "Today's crop care").eq("action_route", route).maybeSingle();
    if (existing) continue;
    await admin.from("notifications").insert({
      recipient_id: recipientId,
      title: "Today's crop care",
      message: `${count} crop task${count === 1 ? " is" : "s are"} due or upcoming in the next 24 hours.`,
      notification_type: "Crop Reminder",
      action_route: route,
    });
  }
}

function expectedStage(planValue: unknown, ageDays: number, observedStage: string) {
  const plan = array(planValue).filter((item): item is Json => typeof item === "object" && item !== null);
  let stage = observedStage;
  for (const item of plan) {
    const start = number(item.start_day);
    if (start !== null && ageDays >= start) stage = String(item.stage ?? stage);
  }
  return stage;
}

function coefficientForStage(coefficients: Json, stage: string, key: string) {
  const normalized = normalize(stage);
  if (normalized.includes("seed") || normalized.includes("germinat")) return number(coefficients.initial) ?? (key === "calamansi" ? 0.65 : 0.4);
  if (normalized.includes("flower") || normalized.includes("pod") || normalized.includes("peg") || normalized.includes("fruit")) return number(coefficients.mid) ?? 1;
  if (normalized.includes("harvest") || normalized.includes("matur")) return number(coefficients.late) ?? 0.7;
  return number(coefficients.development) ?? 0.75;
}

function formatWater(mm: number, liters: number | null) {
  return liters === null ? `${mm} mm after field confirmation` : `${mm} mm (${liters} L for the recorded area)`;
}
function relation(value: unknown): Json | null {
  if (Array.isArray(value)) return value[0] && typeof value[0] === "object" ? value[0] as Json : null;
  return value && typeof value === "object" ? value as Json : null;
}
function array(value: unknown): unknown[] { return Array.isArray(value) ? value : []; }
function stringArray(value: unknown): string[] { return Array.isArray(value) ? value.map(String) : []; }
function numberArray(value: unknown): number[] { return Array.isArray(value) ? value.map((item) => number(item) ?? 0) : []; }
function number(value: unknown): number | null { const parsed = Number(value); return Number.isFinite(parsed) ? parsed : null; }
function sum(values: number[]) { return values.reduce((total, value) => total + value, 0); }
function max(values: number[]) { return values.length ? Math.max(...values) : 0; }
function average(values: number[]) { return values.length ? sum(values) / values.length : null; }
function isNumber(value: unknown): value is number { return typeof value === "number" && Number.isFinite(value); }
function round(value: number, places: number) { const factor = 10 ** places; return Math.round(value * factor) / factor; }
function normalize(value: string) { return value.trim().toLowerCase(); }
function hourStart(value: Date) { const date = new Date(value); date.setMinutes(0, 0, 0); return date; }
function dateKey(value: Date) { return value.toISOString().slice(0, 10); }
function addDays(value: string, days: number) { const date = new Date(value); date.setUTCDate(date.getUTCDate() + days); return date.toISOString().slice(0, 10); }
function required(name: string) { const value = Deno.env.get(name); if (!value) throw new Error(`Missing ${name}`); return value; }
function reply(body: Json, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}
