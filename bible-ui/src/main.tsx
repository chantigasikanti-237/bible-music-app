
  import { createRoot } from "react-dom/client";
  import App from "./app/App.tsx";
  import "./styles/index.css";

  // Applied here, before React renders anything, so a saved dark-mode
  // preference takes effect on first paint no matter which route the user
  // lands on - Profile's toggle only runs this same class change when its
  // own screen is mounted, which does nothing for a reload that opens
  // straight to Home.
  if (localStorage.getItem("theme") === "dark") {
    document.documentElement.classList.add("dark");
  }

  createRoot(document.getElementById("root")!).render(<App />);
