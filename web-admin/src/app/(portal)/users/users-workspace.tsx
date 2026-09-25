"use client";

import type { FormEvent, ReactNode } from "react";
import { useActionState, useCallback, useEffect, useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  BadgeCheck,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Check,
  Eye,
  EyeOff,
  Filter,
  IdCard,
  LockKeyhole,
  Mail,
  Plus,
  Phone,
  Search,
  ShieldCheck,
  UserCog,
  Users,
  X,
} from "lucide-react";
import { createUserAction, updateUserAction } from "@/app/(portal)/users/actions";
import { useConfirmationDialog } from "@/components/confirmation-dialog";
import { useActionFeedback } from "@/components/action-feedback";
import type { AdminUser, UserRole, UsersSummary } from "@/lib/users";
import styles from "./page.module.css";

type Props = {
  users: AdminUser[];
  roles: UserRole[];
  summary: UsersSummary | null;
};

const PAGE_SIZE = 8;

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("en-PH", {
    month: "short",
    day: "numeric",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  }).format(new Date(value));
}

function roleTone(roleName: string) {
  if (roleName === "System Administrator") return styles.adminBadge;
  if (roleName.includes("Inventory")) return styles.inventoryBadge;
  if (roleName.includes("Planting")) return styles.plantingBadge;
  return styles.managerBadge;
}

export function UsersWorkspace({ users, roles, summary }: Props) {
  const [query, setQuery] = useState("");
  const [roleFilter, setRoleFilter] = useState("all");
  const [statusFilter, setStatusFilter] = useState("All");
  const [sortBy, setSortBy] = useState("Newest");
  const [page, setPage] = useState(1);
  const [selectedUser, setSelectedUser] = useState<AdminUser | null>(null);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const { notify: sendFeedback } = useActionFeedback();
  const router = useRouter();

  const filteredUsers = useMemo(() => {
    const needle = query.trim().toLowerCase();

    return users.filter((user) => {
      const matchesQuery =
        !needle ||
        [
          user.employeeId,
          user.username,
          user.email,
          user.fullName,
          user.roleName,
        ].some((value) => value.toLowerCase().includes(needle));

      const matchesRole = roleFilter === "all" || user.roleName === roleFilter;
      const matchesStatus =
        statusFilter === "All" ||
        (statusFilter === "Active" ? user.isActive : !user.isActive);

      return matchesQuery && matchesRole && matchesStatus;
    }).sort((left, right) => {
      if (sortBy === "Name") return left.fullName.localeCompare(right.fullName);
      if (sortBy === "Role") return left.roleName.localeCompare(right.roleName);
      if (sortBy === "Status") return Number(right.isActive) - Number(left.isActive);
      return new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime();
    });
  }, [query, roleFilter, sortBy, statusFilter, users]);

  const totalPages = Math.max(1, Math.ceil(filteredUsers.length / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages);
  const pageStart = Math.min(Math.max(currentPage - 1, 1), Math.max(totalPages - 2, 1));
  const pageNumbers = Array.from({ length: Math.min(3, totalPages) }, (_, index) => pageStart + index);
  const visibleUsers = filteredUsers.slice(
    (currentPage - 1) * PAGE_SIZE,
    currentPage * PAGE_SIZE,
  );

  const farmManagers = users.filter((user) => user.roleName.includes("Manager")).length;

  const notify = useCallback((message: string, tone: "success" | "error" = "success") => sendFeedback({ tone, text: message }), [sendFeedback]);

  return (
    <>
      <section className={styles.metricGrid} aria-label="User summary">
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <Users size={20} />
            </span>
            <p>Total users</p>
          </div>
          <strong>{summary?.totalUsers ?? users.length}</strong>
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <BadgeCheck size={20} />
            </span>
            <p>Active users</p>
          </div>
          <strong>{summary?.activeUsers ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <LockKeyhole size={20} />
            </span>
            <p>Inactive users</p>
          </div>
          <strong>{summary?.inactiveUsers ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <ShieldCheck size={20} />
            </span>
            <p>Administrators</p>
          </div>
          <strong>{summary?.administrators ?? 0}</strong>
        </article>
        <article className={styles.metric}>
          <div className={styles.metricMeta}>
            <span className={styles.metricIcon} aria-hidden="true">
              <UserCog size={20} />
            </span>
            <p>Farm managers</p>
          </div>
          <strong>{farmManagers}</strong>
        </article>
      </section>

      <section className={styles.quickActions}>
        <div>
          <p className={styles.eyebrow}>Quick action</p>
          <h2>Create a user account</h2>
          <span>Create staff accounts and manage their roles, permissions, and status.</span>
        </div>
        <button
          className={styles.actionButton}
          type="button"
          onClick={() => setShowCreateModal(true)}
        >
          <span className={styles.actionButtonText}>Create User</span>
          <span className={styles.actionButtonIcon}>
            <Plus size={20} />
          </span>
        </button>
      </section>

      <section className={styles.listSection}>
        <div className={styles.sectionHeader}>
          <div>
            <p className={styles.eyebrow}>User list</p>
            <h2>Managed users</h2>
          </div>
          <span>{filteredUsers.length} shown</span>
        </div>

        <div className={styles.filters}>
          <label className={styles.searchBox}>
            Search
            <Search size={17} />
            <input
              value={query}
              onChange={(event) => {
                setQuery(event.target.value);
                setPage(1);
              }}
              placeholder="Search name, email, username, role..."
            />
          </label>
          <FilterSelect
            icon={<Filter size={17} />}
            label="Role"
            options={["all", ...roles.map((role) => role.roleName)]}
            value={roleFilter}
            displayValue={roleFilter === "all" ? "All roles" : roleFilter}
            onChange={(value) => {
              setRoleFilter(value);
              setPage(1);
            }}
          />
          <FilterSelect
            icon={<BadgeCheck size={17} />}
            label="Status"
            options={["All", "Active", "Inactive"]}
            value={statusFilter}
            onChange={(value) => {
              setStatusFilter(value);
              setPage(1);
            }}
          />
          <FilterSelect
            icon={<ChevronDown size={17} />}
            label="Sort"
            options={["Newest", "Name", "Role", "Status"]}
            value={sortBy}
            onChange={(value) => {
              setSortBy(value);
              setPage(1);
            }}
          />
        </div>

        {visibleUsers.length === 0 ? (
          <div className={styles.emptyState}>
            <strong>No users found.</strong>
            <span>Try adjusting the search or filters.</span>
          </div>
        ) : (
          <div className={styles.userTable}>
              <div className={styles.tableHead}>
                <span>User</span>
                <span>Full name</span>
                <span>Email</span>
                <span>Role</span>
                <span>Status</span>
                <span>Joined</span>
                <span>Actions</span>
              </div>
              {visibleUsers.map((user) => (
                <article className={styles.tableRow} key={user.id}>
                  <div className={styles.userIdentity} data-label="User">
                    <strong>{user.employeeId}</strong>
                    <span>@{user.username}</span>
                  </div>
                  <strong data-label="Full name">{user.fullName}</strong>
                  <span className={styles.muted} data-label="Email">{user.email}</span>
                  <div className={styles.tableBadgeCell} data-label="Role">
                    <span className={`${styles.badge} ${roleTone(user.roleName)}`}>{user.roleName}</span>
                  </div>
                  <div className={styles.tableBadgeCell} data-label="Status">
                    <span className={`${styles.statusBadge} ${user.isActive ? styles.activeBadge : styles.inactiveBadge}`}>
                      {user.isActive ? "Active" : "Inactive"}
                    </span>
                  </div>
                  <span className={styles.muted} data-label="Joined">{formatDateTime(user.createdAt)}</span>
                  <div className={styles.tableActionCell} data-label="Actions">
                    <button
                      className={styles.iconButton}
                      type="button"
                      aria-label={`Manage ${user.fullName}`}
                      onClick={() => setSelectedUser(user)}
                    >
                      <Eye size={18} />
                    </button>
                  </div>
                </article>
              ))}

              <div className={styles.paginationBar} aria-label="User pagination">
                <button
                  aria-label="Previous user page"
                  disabled={currentPage === 1}
                  type="button"
                  onClick={() => setPage((value) => Math.max(1, value - 1))}
                >
                  <ChevronLeft size={17} />
                </button>
                <div className={styles.pageNumbers}>
                  {pageNumbers.map((number) => (
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
                  aria-label="Next user page"
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

      {selectedUser ? (
        <UserModal
          user={selectedUser}
          roles={roles}
          onClose={() => setSelectedUser(null)}
          onSubmit={() => {
            setSelectedUser(null);
            router.refresh();
            notify("User profile updated.");
          }}
          onError={(message) => notify(message, "error")}
        />
      ) : null}

      {showCreateModal ? (
        <CreateUserModal
          roles={roles}
          onClose={() => setShowCreateModal(false)}
          onNotify={notify}
        />
      ) : null}

    </>
  );
}

function FilterSelect({
  options,
  value,
  label,
  displayValue,
  icon,
  onChange,
}: {
  options: string[];
  value: string;
  label: string;
  displayValue?: string;
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
          <span className={styles.themedSelectValue}>{displayValue ?? value}</span>
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
                <span>{option === "all" ? "All roles" : option}</span>
                {option === value ? <Check size={15} /> : null}
              </button>
            ))}
          </div>
        ) : null}
      </div>
    </label>
  );
}

function UserModal({
  user,
  roles,
  onClose,
  onError,
  onSubmit,
}: {
  user: AdminUser;
  roles: UserRole[];
  onClose: () => void;
  onError: (message: string) => void;
  onSubmit: () => void;
}) {
  const currentRole = roles.find((role) => role.roleName === user.roleName);
  const [pending, startTransition] = useTransition();
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const router = useRouter();

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;

    const formData = new FormData(form);
    const roleChanged = String(formData.get("role_id")) !== (currentRole?.id ?? "");
    const statusChanged = String(formData.get("is_active")) !== String(user.isActive);
    if (roleChanged || statusChanged) {
      const confirmed = await confirm({
        title: "Update account access?",
        message: `This will change the role or access status for ${user.fullName}.`,
        confirmLabel: "Update access",
      });
      if (!confirmed) return;
    }

    startTransition(async () => {
      try {
        await updateUserAction(formData);
        router.refresh();
        onSubmit();
      } catch (error) {
        onError(error instanceof Error ? error.message : "Unable to save user profile.");
      }
    });
  }

  return (
    <div className={styles.modalBackdrop} data-ui-backdrop="true">
      <div className={styles.modal}>
        <div className={styles.modalHeader}>
          <div>
            <p className={styles.eyebrow}>Manage user</p>
            <h2>{user.fullName}</h2>
          </div>
          <button className={styles.closeButton} type="button" onClick={onClose}>
            <X size={20} />
          </button>
        </div>

        <div className={styles.detailGrid}>
          <div className={styles.detailCard}>
            <IdCard size={18} />
            <span>Employee ID</span>
            <strong>{user.employeeId}</strong>
          </div>
          <div className={styles.detailCard}>
            <Mail size={18} />
            <span>Email</span>
            <strong>{user.email}</strong>
          </div>
          <div className={styles.detailCard}>
            <BadgeCheck size={18} />
            <span>Joined</span>
            <strong>{formatDateTime(user.createdAt)}</strong>
          </div>
        </div>

        <form
          className={styles.manageForm}
          onSubmit={handleSubmit}
        >
          <input name="user_id" type="hidden" value={user.id} />
          <label>
            First name
            <input name="first_name" defaultValue={user.firstName} required />
          </label>
          <label>
            Middle initial
            <input name="middle_initial" defaultValue={user.middleInitial} maxLength={1} />
          </label>
          <label>
            Last name
            <input name="last_name" defaultValue={user.lastName} required />
          </label>
          <label>
            Role
            <ThemedSelect
              icon={<ShieldCheck size={16} />}
              name="role_id"
              options={roles.map((role) => ({
                value: role.id,
                label: role.roleName,
              }))}
              defaultValue={currentRole?.id ?? ""}
            />
          </label>
          <label>
            Account status
            <ThemedSelect
              icon={<BadgeCheck size={16} />}
              name="is_active"
              options={[
                { value: "true", label: "Active" },
                { value: "false", label: "Inactive" },
              ]}
              defaultValue={String(user.isActive)}
            />
          </label>
          <div className={styles.formActions}>
            <button className={styles.primaryActionButton} disabled={pending} type="submit">
              <span>{pending ? "Saving..." : "Save Profile"}</span>
            </button>
          </div>
        </form>
        {confirmationDialog}
      </div>
    </div>
  );
}

function CreateUserModal({
  roles,
  onClose,
  onNotify,
}: {
  roles: UserRole[];
  onClose: () => void;
  onNotify: (message: string, tone?: "success" | "error") => void;
}) {
  const [state, formAction, pending] = useActionState(createUserAction, {
    message: "",
    success: false,
  });
  const confirmedRef = useRef(false);
  const [showPassword, setShowPassword] = useState(false);
  const { confirm, confirmationDialog } = useConfirmationDialog();
  const router = useRouter();
  const roleOptions = roles.map((role) => ({
    value: role.id,
    label: role.roleName,
  }));

  useEffect(() => {
    if (!state.message) {
      return;
    }

    onNotify(state.message, state.success ? "success" : "error");

    if (state.success) {
      onClose();
      router.refresh();
    }
  }, [onClose, onNotify, router, state]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    const form = event.currentTarget;

    if (confirmedRef.current) {
      confirmedRef.current = false;
      return;
    }

    event.preventDefault();

    const confirmed = await confirm({
      title: "Create user account?",
      message: "This will create a staff account with the selected role and access status.",
      confirmLabel: "Create account",
    });

    if (!confirmed) {
      return;
    }

    confirmedRef.current = true;
    form.requestSubmit();
  }

  return (
    <div className={styles.modalBackdrop} data-ui-backdrop="true">
      <div className={styles.modal}>
        <div className={styles.modalHeader}>
          <div className={styles.modalTitle}>
            <div>
              <p className={styles.eyebrow}>Create user</p>
              <h2>New staff account</h2>
            </div>
          </div>
          <button
            className={styles.closeButton}
            type="button"
            aria-label="Close create user modal"
            onClick={onClose}
          >
            <X size={20} />
          </button>
        </div>

        <div className={styles.noticeCard}>
          <ShieldCheck size={20} />
          <div>
            <strong>Secure account creation</strong>
            <span>
              This creates a Supabase Auth account and links it to a SeedRover role.
            </span>
          </div>
        </div>

        <form
          action={formAction}
          className={`${styles.manageForm} ${styles.createUserForm}`}
          onSubmit={handleSubmit}
        >
          <label>
            First name
            <input name="first_name" placeholder="e.g. Juan" required />
          </label>
          <label>
            Middle initial
            <input maxLength={1} name="middle_initial" placeholder="e.g. D" />
          </label>
          <label>
            Last name
            <input name="last_name" placeholder="e.g. Dela Cruz" required />
          </label>
          <label>
            Username
            <input
              name="username"
              placeholder="seedrover_staff"
              pattern="[a-z0-9_]{3,32}"
              required
            />
          </label>
          <label>
            Email address
            <input name="email" placeholder="staff@seedrover.local" required type="email" />
          </label>
          <label>
            Contact number
            <span className={styles.inputWithIcon}>
              <Phone size={16} />
              <input name="contact_number" placeholder="e.g. 0912 345 6789" />
            </span>
          </label>
          <label className={styles.passwordLabel}>
            Temporary password
            <input
              minLength={8}
              name="temporary_password"
              placeholder="Set temporary password"
              required
              type={showPassword ? "text" : "password"}
            />
            <button
              aria-label={showPassword ? "Hide temporary password" : "Show temporary password"}
              aria-pressed={showPassword}
              className={styles.passwordToggle}
              type="button"
              onClick={() => setShowPassword((current) => !current)}
            >
              {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
            </button>
          </label>
          <label>
            Role
            <ThemedSelect
              icon={<ShieldCheck size={16} />}
              name="role_id"
              options={roleOptions}
              defaultValue={roles[0]?.id ?? ""}
            />
          </label>
          <label>
            Account status
            <ThemedSelect
              icon={<BadgeCheck size={16} />}
              name="is_active"
              options={[
                { value: "true", label: "Active" },
                { value: "false", label: "Inactive" },
              ]}
              defaultValue="true"
            />
          </label>
          <label>
            Access note
            <input name="access_note" placeholder="e.g. Assigned to greenhouse operations" />
          </label>

          <div className={styles.formActions}>
            <button className={styles.primaryActionButton} disabled={pending} type="submit">
              <span>{pending ? "Creating..." : "Create Account"}</span>
            </button>
          </div>
        </form>
        {confirmationDialog}
      </div>
    </div>
  );
}

function ThemedSelect({
  options,
  defaultValue,
  icon,
  name,
}: {
  options: { value: string; label: string }[];
  defaultValue: string;
  icon?: ReactNode;
  name?: string;
}) {
  const initialValue = options.find((option) => option.value === defaultValue)?.value ?? options[0]?.value ?? "";
  const [selectedValue, setSelectedValue] = useState(initialValue);
  const [open, setOpen] = useState(false);
  const selectedOption = options.find((option) => option.value === selectedValue);

  return (
    <div className={styles.themedSelect}>
      {name ? <input name={name} type="hidden" value={selectedValue} /> : null}
      <button
        aria-expanded={open}
        className={styles.themedSelectButton}
        type="button"
        onClick={() => setOpen((current) => !current)}
      >
        {icon ? <span className={styles.themedSelectIcon}>{icon}</span> : null}
        <span className={styles.themedSelectValue}>{selectedOption?.label ?? "Select"}</span>
        <ChevronDown className={styles.themedSelectChevron} size={16} />
      </button>
      {open ? (
        <div className={styles.themedSelectMenu}>
          {options.map((option) => (
            <button
              className={styles.themedSelectOption}
              data-selected={option.value === selectedValue}
              type="button"
              onClick={() => {
                setSelectedValue(option.value);
                setOpen(false);
              }}
              key={option.value}
            >
              <span>{option.label}</span>
              {option.value === selectedValue ? <Check size={15} /> : null}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}
