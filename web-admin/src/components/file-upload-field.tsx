"use client";

import { useState } from "react";
import { FileUp, ImageUp } from "lucide-react";
import styles from "@/components/file-upload-field.module.css";

type FileUploadFieldProps = {
  accept: string;
  disabled?: boolean;
  helperText: string;
  kind?: "image" | "document";
  label: string;
  name: string;
  prompt: string;
  required?: boolean;
};

export function FileUploadField({
  accept,
  disabled = false,
  helperText,
  kind = "image",
  label,
  name,
  prompt,
  required = false,
}: FileUploadFieldProps) {
  const [fileName, setFileName] = useState("");
  const UploadIcon = kind === "document" ? FileUp : ImageUp;

  return (
    <label className={styles.field}>
      <span>{label}</span>
      <div className={styles.uploadArea} data-selected={fileName ? "true" : "false"}>
        <input
          accept={accept}
          className={styles.input}
          disabled={disabled}
          name={name}
          required={required}
          type="file"
          onChange={(event) => setFileName(event.currentTarget.files?.[0]?.name ?? "")}
        />
        <span className={styles.icon} aria-hidden="true">
          <UploadIcon size={20} strokeWidth={1.8} />
        </span>
        <span className={styles.copy}>
          <span className={styles.fileName}>{fileName || prompt}</span>
          <small>{fileName ? "File selected" : helperText}</small>
        </span>
        <span className={styles.browse} aria-hidden="true">BROWSE</span>
      </div>
    </label>
  );
}
