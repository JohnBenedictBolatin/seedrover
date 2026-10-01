"use server";

import { revalidatePath } from "next/cache";
import { requireAdminRole } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { customerKey } from "@/lib/customers";
import { writeActivityLog } from "@/lib/activity-log";
import { normalizeContactNumber } from "@/lib/contact-number.mjs";
import { parseDatabaseDecimal } from "@/lib/field-validation.mjs";

function text(formData: FormData, key: string, fallback = "") {
  return String(formData.get(key) ?? fallback).trim();
}

function databaseSetupMessage(error: { message?: string }) {
  const message = error.message ?? "";

  if (message.includes("customer_discounts") || message.includes("schema cache")) {
    return "Discounts database is not ready yet. Apply the latest Supabase migration, then try releasing the discount again.";
  }

  return message;
}

function parseNumber(value: FormDataEntryValue | null) {
  return parseDatabaseDecimal(value, "Discount value");
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

  const customerName = "Anyone with the code";
  const customerContact = normalizeContactNumber("Not provided", {
    allowLegacy: true,
  }) ?? "Not provided";
  const code = text(formData, "discount_code").toUpperCase();
  const discountType = text(formData, "discount_type", "Percent");
  const discountValue = parseNumber(formData.get("discount_value"));
  const validUntil = text(formData, "valid_until");

  if (!code) {
    throw new Error("Discount code is required.");
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
    const today = new Intl.DateTimeFormat("en-CA", {
      timeZone: "Asia/Manila",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(new Date());

    if (!/^\d{4}-\d{2}-\d{2}$/.test(validUntil) || validUntil < today) {
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

  await writeActivityLog(supabase, {
    userId: user.id,
    activity: "Customer discount released",
    description: `${code} was released for anyone who enters it.`,
    module: "Customers",
  });

  revalidatePath("/customers");
  revalidatePath("/sales");

  return { code };
}
