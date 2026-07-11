import { useNavigate, useLocation } from 'react-router';
import { SongsBook } from '../components/SongsBook';

interface OpenHymnRequest {
  songId: string;
  title: string;
  languageCode: string;
}

export function HymnsPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const openHymn = (location.state as { openHymn?: OpenHymnRequest } | null)?.openHymn ?? null;
  return <SongsBook standalone isOpen onClose={() => navigate(-1)} openHymn={openHymn} />;
}
