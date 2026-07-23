import { useState, useRef, useCallback } from 'react';
import { motion } from 'motion/react';

const FRAME_SIZE = 288; // px — square crop viewport (displayed as a circle)
const OUTPUT_SIZE = 400; // px — exported square photo
const MAX_ZOOM = 3;

interface PhotoCropSheetProps {
  imageUrl: string;
  onCancel: () => void;
  onDone: (dataUrl: string) => void;
}

// Full-screen pan/zoom crop, WhatsApp-style: drag to reposition, pinch/wheel/
// slider to zoom, Cancel/Done in the header. Built on the same canvas-export
// approach the app already uses for photo resizing — no crop library needed.
export function PhotoCropSheet({ imageUrl, onCancel, onDone }: PhotoCropSheetProps) {
  const imgRef = useRef<HTMLImageElement>(null);
  const [naturalSize, setNaturalSize] = useState<{ w: number; h: number } | null>(null);
  const [baseScale, setBaseScale] = useState(1);
  const [zoom, setZoom] = useState(1);
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const dragRef = useRef<{ startX: number; startY: number; startOffsetX: number; startOffsetY: number } | null>(null);
  const pinchRef = useRef<{ startDist: number; startZoom: number } | null>(null);

  const clampOffset = useCallback((x: number, y: number, scale: number, size: { w: number; h: number } | null = naturalSize) => {
    if (!size) return { x, y };
    const dispW = size.w * baseScale * scale;
    const dispH = size.h * baseScale * scale;
    const minX = Math.min(0, FRAME_SIZE - dispW);
    const minY = Math.min(0, FRAME_SIZE - dispH);
    return {
      x: Math.max(minX, Math.min(0, x)),
      y: Math.max(minY, Math.min(0, y)),
    };
  }, [naturalSize, baseScale]);

  const handleImgLoad = () => {
    const img = imgRef.current;
    if (!img) return;
    const w = img.naturalWidth, h = img.naturalHeight;
    const scale = FRAME_SIZE / Math.min(w, h);
    const dispW = w * scale, dispH = h * scale;
    setNaturalSize({ w, h });
    setBaseScale(scale);
    setZoom(1);
    setOffset({ x: (FRAME_SIZE - dispW) / 2, y: (FRAME_SIZE - dispH) / 2 });
  };

  const applyZoom = (nextZoomRaw: number, size = naturalSize) => {
    const nextZoom = Math.min(MAX_ZOOM, Math.max(1, nextZoomRaw));
    const cx = FRAME_SIZE / 2, cy = FRAME_SIZE / 2;
    const prevScale = baseScale * zoom;
    const nextScale = baseScale * nextZoom;
    const imgX = (cx - offset.x) / prevScale;
    const imgY = (cy - offset.y) / prevScale;
    const nextOffset = clampOffset(cx - imgX * nextScale, cy - imgY * nextScale, nextZoom, size);
    setZoom(nextZoom);
    setOffset(nextOffset);
  };

  const onPointerDown = (e: React.PointerEvent) => {
    // Only the primary pointer drags — a second touch (pinch) shouldn't
    // reset the drag anchor to its own position.
    if (!e.isPrimary) return;
    (e.target as Element).setPointerCapture(e.pointerId);
    dragRef.current = { startX: e.clientX, startY: e.clientY, startOffsetX: offset.x, startOffsetY: offset.y };
  };
  const onPointerMove = (e: React.PointerEvent) => {
    if (!dragRef.current || pinchRef.current) return;
    const dx = e.clientX - dragRef.current.startX;
    const dy = e.clientY - dragRef.current.startY;
    setOffset(clampOffset(dragRef.current.startOffsetX + dx, dragRef.current.startOffsetY + dy, zoom));
  };
  const onPointerUp = () => { dragRef.current = null; };

  // Two-finger pinch to zoom (touch only) — tracked separately from the
  // single-pointer drag above since Pointer Events report each touch as an
  // independent stream, not a combined gesture.
  const onTouchMove = (e: React.TouchEvent) => {
    if (e.touches.length !== 2) { pinchRef.current = null; return; }
    e.preventDefault();
    const [t1, t2] = [e.touches[0], e.touches[1]];
    const dist = Math.hypot(t2.clientX - t1.clientX, t2.clientY - t1.clientY);
    if (!pinchRef.current) {
      pinchRef.current = { startDist: dist, startZoom: zoom };
      return;
    }
    const nextZoom = pinchRef.current.startZoom * (dist / pinchRef.current.startDist);
    applyZoom(nextZoom);
  };
  const onTouchEnd = (e: React.TouchEvent) => {
    if (e.touches.length < 2) pinchRef.current = null;
  };

  const onWheel = (e: React.WheelEvent) => {
    e.preventDefault();
    applyZoom(zoom - e.deltaY * 0.002);
  };

  const handleDone = () => {
    if (!naturalSize || !imgRef.current) return;
    const dispScale = baseScale * zoom;
    const srcW = FRAME_SIZE / dispScale;
    const srcH = FRAME_SIZE / dispScale;
    const srcX = -offset.x / dispScale;
    const srcY = -offset.y / dispScale;
    const canvas = document.createElement('canvas');
    canvas.width = OUTPUT_SIZE;
    canvas.height = OUTPUT_SIZE;
    canvas.getContext('2d')!.drawImage(imgRef.current, srcX, srcY, srcW, srcH, 0, 0, OUTPUT_SIZE, OUTPUT_SIZE);
    onDone(canvas.toDataURL('image/jpeg', 0.85));
  };

  return (
    <motion.div
      initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
      className="fixed inset-0 z-[60] bg-black flex flex-col"
    >
      <div className="flex items-center justify-between px-4 pt-12 pb-4 flex-shrink-0">
        <button onClick={onCancel} className="text-white/90 hover:text-white font-sans text-base px-2 py-1 cursor-pointer">
          Cancel
        </button>
        <span className="text-white font-sans text-sm font-semibold">Move and Scale</span>
        <button
          onClick={handleDone}
          disabled={!naturalSize}
          className="text-accent font-sans text-base font-semibold px-2 py-1 cursor-pointer disabled:opacity-40"
        >
          Done
        </button>
      </div>

      <div className="flex-1 flex items-center justify-center overflow-hidden">
        <div
          className="relative overflow-hidden touch-none select-none cursor-grab active:cursor-grabbing"
          style={{ width: FRAME_SIZE, height: FRAME_SIZE, borderRadius: '50%', boxShadow: '0 0 0 9999px rgba(0,0,0,0.72)' }}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerCancel={onPointerUp}
          onTouchMove={onTouchMove}
          onTouchEnd={onTouchEnd}
          onWheel={onWheel}
        >
          <img
            ref={imgRef}
            src={imageUrl}
            alt="Crop preview"
            onLoad={handleImgLoad}
            draggable={false}
            className="absolute pointer-events-none max-w-none"
            style={
              naturalSize
                ? { width: naturalSize.w * baseScale * zoom, height: naturalSize.h * baseScale * zoom, left: offset.x, top: offset.y }
                : { opacity: 0 }
            }
          />
        </div>
      </div>

      <div className="px-10 pb-10 flex-shrink-0">
        <input
          type="range"
          min={1}
          max={MAX_ZOOM}
          step={0.01}
          value={zoom}
          onChange={e => applyZoom(Number(e.target.value))}
          disabled={!naturalSize}
          className="w-full accent-accent"
        />
      </div>
    </motion.div>
  );
}
