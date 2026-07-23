// Shared current-user profile, outside any single screen's lifecycle — so
// an avatar/name update made on Personal Information shows up immediately
// on the sidebar/bottom nav and the Profile header too, not just after a
// remount. Mirrors the subscribe/getSnapshot pattern downloadManager.ts
// already uses in this codebase.

export interface UserProfileSnapshot {
  id: string;
  name: string | null;
  email: string;
  photo: string | null;
  emailVerifiedAt: string | null;
}

let profile: UserProfileSnapshot | null = null;
const listeners = new Set<() => void>();

function notify(): void {
  for (const listener of listeners) listener();
}

export function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function getProfileSnapshot(): UserProfileSnapshot | null {
  return profile;
}

export function setProfile(next: UserProfileSnapshot): void {
  profile = next;
  notify();
}

export function clearProfile(): void {
  profile = null;
  notify();
}
