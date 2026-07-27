"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function pingRoverAction() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) throw new Error("Supabase is not configured.");
  const { error } = await supabase.functions.invoke("rover-command", {
    body: { rover_id: "seedrover-01", command: "PING", payload: {} },
  });
  if (error) throw new Error(error.message);
  revalidatePath("/rover-monitor");
}

export async function releaseRoverLeaseAction() {
  const supabase = await createSupabaseServerClient();
  if (!supabase) return;
  await supabase.rpc("release_rover_control_lease", {
    target_rover_id: "seedrover-01",
  });
  revalidatePath("/rover-monitor");
}
