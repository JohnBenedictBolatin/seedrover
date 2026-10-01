"use client";

import { useState } from "react";
import { FileUp, ImageUp } from "lucide-react";
import styles from "@/components/file-upload-field.module.css";
import { MAX_UPLOAD_SIZE_BYTES, MAX_UPLOAD_SIZE_LABEL } from "@/lib/upload-limits";

type FileUploadFieldProps = {
  accept: string;
  disabled?: boolean;
  helperText: string;
  kind?: "image" | "document";
  label: string;
  name: string;
  multiple?: boolean;
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
  multiple = false,
  prompt,
  required = false,
}: FileUploadFieldProps) {
  const [fileName, setFileName] = useState("");
  const [sizeError, setSizeError] = useState("");
  const UploadIcon = kind === "document" ? FileUp : ImageUp;

  return (
    <label className={styles.field}>
      <span>{label}</span>
      <div className={styles.uploadArea} data-selected={fileName ? "true" : "false"}>
        <input
          accept={accept}
          className={styles.input}
          disabled={disabled}
          multiple={multiple}
          name={name}
          required={required}
          type="file"
          onChange={(event) => {
            const files = Array.from(event.currentTarget.files ?? []);
            if (files.some((file) => file.size > MAX_UPLOAD_SIZE_BYTES)) {
              setFileName("");
              setSizeError(`Each file must be ${MAX_UPLOAD_SIZE_LABEL} or smaller.`);
              event.currentTarget.value = "";
              return;
            }
            setSizeError("");
            const selectedLabel = kind === "image" ? "photos" : "files";
            setFileName(multiple && files.length > 1 ? `${files.length} ${selectedLabel} selected` : files[0]?.name ?? "");
          }}
        />
        <span className={styles.icon} aria-hidden="true">
          <UploadIcon size={20} strokeWidth={1.8} />
        </span>
        <span className={styles.copy}>
          <span className={styles.fileName}>{fileName || prompt}</span>
          <small>{sizeError || (fileName ? "File selected" : helperText)}</small>
        </span>
        <span className={styles.browse} aria-hidden="true">BROWSE</span>
      </div>
    </label>
  );
}
