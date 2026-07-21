"use client";

import { useEffect, useState } from "react";
import styles from "@/app/login/page.module.css";

export function LoginThemeSwitch() {
  const [theme, setTheme] = useState<"dark" | "light">("dark");

  useEffect(() => {
    const savedTheme = window.localStorage.getItem("seedrover-theme");
    const nextTheme = savedTheme === "light" ? "light" : "dark";
    document.documentElement.dataset.theme = nextTheme;
    setTheme(nextTheme);
  }, []);

  function toggleTheme() {
    const nextTheme = theme === "dark" ? "light" : "dark";
    document.documentElement.dataset.theme = nextTheme;
    window.localStorage.setItem("seedrover-theme", nextTheme);
    setTheme(nextTheme);
  }

  return (
    <label
      className={styles.themeSwitch}
      title={theme === "dark" ? "Switch to light mode" : "Switch to dark mode"}
    >
      <input
        aria-label={theme === "dark" ? "Switch to light mode" : "Switch to dark mode"}
        checked={theme === "light"}
        className={styles.themeSwitchInput}
        type="checkbox"
        onChange={toggleTheme}
      />
      <span className={styles.themeSwitchToggle} aria-hidden="true">
        <span className={styles.themeMoonsHole}>
          <span className={styles.themeMoonHole} />
          <span className={styles.themeMoonHole} />
          <span className={styles.themeMoonHole} />
        </span>
        <span className={styles.themeBlackClouds}>
          <span className={styles.themeBlackCloud} />
          <span className={styles.themeBlackCloud} />
          <span className={styles.themeBlackCloud} />
        </span>
        <span className={styles.themeClouds}>
          <span className={styles.themeCloud} />
          <span className={styles.themeCloud} />
          <span className={styles.themeCloud} />
          <span className={styles.themeCloud} />
          <span className={styles.themeCloud} />
          <span className={styles.themeCloud} />
          <span className={styles.themeCloud} />
        </span>
        <span className={styles.themeStars}>
          {Array.from({ length: 5 }).map((_, index) => (
            <svg className={styles.themeStar} viewBox="0 0 20 20" key={index}>
              <path d="M 0 10 C 10 10,10 10 ,0 10 C 10 10 , 10 10 , 10 20 C 10 10 , 10 10 , 20 10 C 10 10 , 10 10 , 10 0 C 10 10,10 10 ,0 10 Z" />
            </svg>
          ))}
        </span>
      </span>
    </label>
  );
}
