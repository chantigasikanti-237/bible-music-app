// Local playlist storage for the Music tab. Fully client-side (localStorage) —
// there's no backend playlist API yet, so this mirrors the same pattern as
// music favorites/downloads: simple, per-device, no account sync required.

export interface PlaylistSong {
  videoId: string;
  title: string;
  artist: string;
  image: string;
  language: string;
}

export interface Playlist {
  id: string;
  name: string;
  createdAt: string;
  songs: PlaylistSong[];
}

const KEY = 'music_playlists_v1';

function readAll(): Playlist[] {
  try {
    const raw = JSON.parse(localStorage.getItem(KEY) || '[]');
    return Array.isArray(raw) ? raw : [];
  } catch {
    return [];
  }
}

function writeAll(playlists: Playlist[]): void {
  localStorage.setItem(KEY, JSON.stringify(playlists));
}

export function getPlaylists(): Playlist[] {
  return readAll();
}

export function getPlaylist(id: string): Playlist | null {
  return readAll().find(p => p.id === id) ?? null;
}

export function createPlaylist(name: string): Playlist {
  const playlist: Playlist = {
    id: `pl_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    name: name.trim() || 'Untitled Playlist',
    createdAt: new Date().toISOString(),
    songs: [],
  };
  const all = readAll();
  all.unshift(playlist);
  writeAll(all);
  return playlist;
}

export function renamePlaylist(id: string, name: string): void {
  const trimmed = name.trim();
  if (!trimmed) return;
  const all = readAll();
  const playlist = all.find(p => p.id === id);
  if (playlist) {
    playlist.name = trimmed;
    writeAll(all);
  }
}

export function deletePlaylist(id: string): void {
  writeAll(readAll().filter(p => p.id !== id));
}

export function addSongToPlaylist(id: string, song: PlaylistSong): void {
  const all = readAll();
  const playlist = all.find(p => p.id === id);
  if (!playlist) return;
  if (!playlist.songs.some(s => s.videoId === song.videoId)) {
    playlist.songs.push(song);
    writeAll(all);
  }
}

export function removeSongFromPlaylist(id: string, videoId: string): void {
  const all = readAll();
  const playlist = all.find(p => p.id === id);
  if (!playlist) return;
  playlist.songs = playlist.songs.filter(s => s.videoId !== videoId);
  writeAll(all);
}
