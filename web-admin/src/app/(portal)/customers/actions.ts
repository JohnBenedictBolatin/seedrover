"use server";

import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { customerKey } from "@/lib/customers";

function text(formData: FormData, key: string, fallback = "") {
  return String(formData.get(key) ?? fallback).trim();
}

function parseTags(value: string) {
  return value
    .split(",")
    .map((tag) => tag.trim())
    .filter(Boolean)
    .slice(0, 8);
}

function databaseSetupMessage(error: { message?: string }) {
  const message = error.message ?? "";

  if (message.includes("customer_discounts") || message.includes("schema cache")) {
    return "Discounts database is not ready yet. Apply the latest Supabase migration, then try releasing the discount again.";
  }

  if (message.includes("customers")) {
    return "Customers database is not ready yet. Apply the latest Supabase migration, then try saving the profile again.";
  }

  return message;
}

export async function saveCustomerProfileAction(formData: FormData) {
  await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);

  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    throw new Error("Supabase is not configured.");
  }

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    throw new Error("Sign in before saving customer notes.");
  }

  const displayName = text(formData, "display_name", "Walk-in customer");
  const contactNumber = text(formData, "contact_number", "Not provided");
  const payload = {
    customer_key: customerKey(displayName, contactNumber),
    display_name: displayName,
    contact_number: contactNumber,
    alternate_contact: text(formData, "alternate_contact") || null,
    customer_type: text(formData, "customer_type", "Farm Buyer"),
    tags: parseTags(text(formData, "tags")),
    notes: text(formData, "notes") || null,
    location: text(formData, "location") || null,
    created_by: user.id,
    updated_by: user.id,
  };

  const { error } = await supabase
    .from("customers")
    .upsert(payload, { onConflict: "customer_key" });

  if (error) {
    throw new Error(databaseSetupMessage(error));
  }

  revalidatePath("/customers");
}

function parseNumber(value: FormDataEntryValue | null) {
  const parsed = Number(String(value ?? "").trim());
  return Number.isFinite(parsed) ? parsed : 0;
}

export async function createCustomerDiscountAction(formData: FormData) {
  await requireAdminRole(["System Administrator", "Farm Inventory Manager"]);

  const supabase = await createSupabaseServerClient();

  if (!supabase) {
    throw new Error("Supabase is not configured.");
  }

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    throw new Error("Sign in before releasing discounts.");
  }

  const customerName = text(formData, "customer_name");
  const customerContact = text(formData, "customer_contact", "Not provided");
  const code = text(formData, "discount_code").toUpperCase();
  const discountType = text(formData, "discount_type", "Percent");
  const discountValue = parseNumber(formData.get("discount_value"));
  const validUntil = text(formData, "valid_until");

  if (!customerName || !code) {
    throw new Error("Customer and discount code are required.");
  }

  if (!/^[A-Z0-9_-]{3,32}$/.test(code)) {
    throw new Error("Discount code must be 3-32 characters using letters, numbers, dash, or underscore.");
  }

  if (!["Amount", "Percent"].includes(discountType)) {
    throw new Error("Invalid discount type.");
  }

  if (discountValue <= 0) {
    throw new Error("Discount value must be greater than zero.");
  }

  if (discountType === "Percent" && discountValue > 100) {
    throw new Error("Discount percent cannot be greater than 100.");
  }

  if (validUntil) {
    const expiry = new Date(`${validUntil}T23:59:59`);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (Number.isNaN(expiry.getTime()) || expiry < today) {
      throw new Error("Discount validity date cannot be in the past.");
    }
  }

  const { error } = await supabase.from("customer_discounts").insert({
    discount_code: code,
    customer_key: customerKey(customerName, customerContact),
    customer_name: customerName,
    customer_contact: customerContact,
    discount_type: discountType,
    discount_value: discountValue,
    valid_until: validUntil || null,
    notes: text(formData, "notes") || null,
    status: "Released",
    released_by: user.id,
  });

  if (error) {
    throw new Error(databaseSetupMessage(error));
  }

  revalidatePath("/customers");
  revalidatePath("/sales");

  return { code };
}
