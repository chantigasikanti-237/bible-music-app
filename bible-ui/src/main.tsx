
  import { createRoot } from "react-dom/client";
  import App from "./app/App.tsx";
  import { reportThemeToNativeShell } from "./app/lib/nativeTheme";
  import "./styles/index.css";

  // Applied here, before React renders anything, so a saved dark-mode
  // preference takes effect on first paint no matter which route the user
  // lands on - Profile's toggle only runs this same class change when its
  // own screen is mounted, which does nothing for a reload that opens
  // straight to Home.
  const isDark = localStorage.getItem("theme") === "dark";
  if (isDark) {
    document.documentElement.classList.add("dark");
  }
  reportThemeToNativeShell(isDark);

  createRoot(document.getElementById("root")!).render(<App />);
