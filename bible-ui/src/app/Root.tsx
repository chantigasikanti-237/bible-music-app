import { Outlet } from "react-router";
import { BottomNav } from "./components/BottomNav";

export function Root() {
  return (
    <div className="size-full relative overflow-hidden bg-[#f5f1e8]">
      <BottomNav />
      {/* Absolute fill: starts right of fixed sidebar on md+, full width on mobile */}
      <div id="main-scroll" className="absolute inset-0 left-0 md:left-[72px] xl:left-[220px] overflow-auto pb-16 md:pb-0">
        <Outlet />
      </div>
    </div>
  );
}
