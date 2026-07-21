"use client";

import type { ReactNode } from "react";
import { useMemo, useState } from "react";
import {
  Check,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ClipboardList,
  Filter,
  History,
  LockKeyhole,
  Search,
  ShieldCheck,
  ShoppingCart,
} from "lucide-react";
import type { ActivityLogItem, ActivitySummary } from "@/lib/activity";
import { formatDateTime } from "@/lib/format";
import styles from "./page.module.css";

const ROWS_PER_PAGE = 8;

type Props = {
  logs: ActivityLogItem[];
  summary: ActivitySummary | null;
};

function moduleTone(module: string) {
  if (["System", "Users", "Notifications"].includes(module)) return styles.systemBadge;
  if (["Sales", "Stocks", "Inventory", "Customers"].includes(module)) {
    return styles.operationsBadge;
  }
  if (["Authentication"].includes(module)) return styles.authBadge;
  return styles.farmBadge;
}

export function ActivityLogWorkspace({ logs, summary }: Props) {
  const [query, setQuery] = useState("");
  const [moduleFilter, setModuleFilter] = useState("All");
  const [sortBy, setSortBy] = useState("Newest");
  const [page, setPage] = useState(1);

  const moduleOptions = useMemo(
    () => ["All", ...Array.from(new Set(logs.map((log) => log.module))).sort()],
    [logs],
  );

  const filteredLogs = useMemo(() => {
    const needle = query.trim().toLowerCase();

    return logs
      .filter((log) => {
        const haystack = [
          log.activity,
          log.description,
          log.module,
          log.userName,
          log.createdAt,
        ]
          .join(" ")
          .toLowerCase();

        return (
          (!needle || haystack.includes(needle)) &&
          (moduleFilter === "All" || log.module === moduleFilter)
        );
      })
      .sort((left, right) => {
        if (sortBy === "Oldest") {
          return new Date(left.createdAt).getTime() - new Date(right.createdAt).getTime();
        }

        if (sortBy === "Module") {
          return left.module.localeCompare(right.module);
        }

        if (sortBy === "User") {
          return left.userName.localeCompare(right.userName);
        }

        return new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime();
      });
  }, [logs, moduleFilter, query, sortBy]);

  const totalPages = Math.max(1, Math.ceil(filteredLogs.length / ROWS_PER_PAGE));
  const currentPage = Math.min(page, totalPages);
  const visibleLogs = filteredLogs.slice(
    (currentPage - 1) * ROWS_PER_PAGE,
    currentPage * ROWS_PER_PAGE,
  );

  return (
    <>
      <section className={styles.metricGrid} aria-label="Activity summary">
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon}>
              <ClipboardList size={20} />
            </span>
            <p>Recent records</p>
          </div>
          <strong>{summary?.total ?? logs.length}</strong>
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon}>
              <LockKeyhole size={20} />
            </span>
            <p>Authentication</p>
          </div>
          <strong>{summary?.authentication ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon}>
              <ShoppingCart size={20} />
            </span>
            <p>Sales / Stocks</p>
          </div>
          <strong>{summary?.salesAndStocks ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon}>
              <ShieldCheck size={20} />
            </span>
            <p>System</p>
          </div>
          <strong>{summary?.system ?? 0}</strong>
        </article>
      </section>

      <section className={styles.listSection}>
        <div className={styles.sectionHeader}>
          <div>
            <p className={styles.eyebrow}>Audit trail</p>
            <h2>Activity records</h2>
          </div>
          <span>{filteredLogs.length} shown</span>
        </div>

        <div className={styles.filters}>
          <label className={styles.searchBox}>
            Search
            <Search size={17} />
            <input
              placeholder="Search activity, module, user..."
              value={query}
              onChange={(event) => {
                setQuery(event.target.value);
                setPage(1);
              }}
            />
          </label>
          <FilterSelect
            icon={<Filter size={17} />}
            label="Module"
            options={moduleOptions}
            value={moduleFilter}
            onChange={(value) => {
              setModuleFilter(value);
              setPage(1);
            }}
          />
          <FilterSelect
            icon={<ChevronDown size={17} />}
            label="Sort"
            options={["Newest", "Oldest", "Module", "User"]}
            value={sortBy}
            onChange={(value) => {
              setSortBy(value);
              setPage(1);
            }}
          />
        </div>

        {visibleLogs.length === 0 ? (
          <div className={styles.emptyState}>
            <strong>No activity records found.</strong>
            <span>Try adjusting the filters or wait for system actions to be recorded.</span>
          </div>
        ) : (
          <div className={styles.logTable}>
            <div className={styles.tableHead}>
              <span>Activity</span>
              <span>Module</span>
              <span>User</span>
              <span>Date / Time</span>
            </div>
            {visibleLogs.map((log) => (
              <article className={styles.tableRow} key={log.id}>
                <div className={styles.activityCell}>
                  <strong>{log.activity}</strong>
                  <span>{log.description}</span>
                </div>
                <span className={`${styles.moduleBadge} ${moduleTone(log.module)}`}>
                  {log.module}
                </span>
                <span className={styles.userCell}>{log.userName}</span>
                <time className={styles.dateCell}>{formatDateTime(log.createdAt)}</time>
              </article>
            ))}
            <div className={styles.paginationBar} aria-label="Activity log pagination">
              <button
                aria-label="Previous activity page"
                disabled={currentPage === 1}
                type="button"
                onClick={() => setPage((value) => Math.max(1, value - 1))}
              >
                <ChevronLeft size={17} />
              </button>
              <div className={styles.pageNumbers}>
                {Array.from({ length: totalPages }, (_, index) => index + 1).map((number) => (
                  <button
                    aria-current={number === currentPage ? "page" : undefined}
                    data-active={number === currentPage ? "true" : "false"}
                    type="button"
                    onClick={() => setPage(number)}
                    key={number}
                  >
                    {number}
                  </button>
                ))}
              </div>
              <button
                aria-label="Next activity page"
                disabled={currentPage === totalPages}
                type="button"
                onClick={() => setPage((value) => Math.min(totalPages, value + 1))}
              >
                <ChevronRight size={17} />
              </button>
            </div>
          </div>
        )}
      </section>
    </>
  );
}

function FilterSelect({
  options,
  value,
  label,
  icon,
  onChange,
}: {
  options: string[];
  value: string;
  label: string;
  icon?: ReactNode;
  onChange: (value: string) => void;
}) {
  const [open, setOpen] = useState(false);

  return (
    <label className={styles.themedSelect}>
      <div className={styles.themedSelectControl}>
        <button
          aria-expanded={open}
          className={styles.themedSelectButton}
          type="button"
          onClick={() => setOpen((current) => !current)}
        >
          {icon ? <span className={styles.themedSelectIcon}>{icon}</span> : null}
          <span className={styles.themedSelectLabel}>{label}</span>
          <span className={styles.themedSelectValue}>{value}</span>
          <ChevronDown className={styles.themedSelectChevron} size={16} />
        </button>
        {open ? (
          <div className={styles.themedSelectMenu}>
            {options.map((option) => (
              <button
                className={styles.themedSelectOption}
                data-selected={option === value}
                type="button"
                onClick={() => {
                  onChange(option);
                  setOpen(false);
                }}
                key={option}
              >
                <span>{option}</span>
                {option === value ? <Check size={15} /> : null}
              </button>
            ))}
          </div>
        ) : null}
      </div>
    </label>
  );
}
