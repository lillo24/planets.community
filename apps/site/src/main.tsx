import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

import { App } from "./App";
import "./styles.css";
import "./header-responsive.css";
import "./launch-polish.css";

const rootElement = document.getElementById("root");

if (!rootElement) {
  throw new Error("PLANETS site root element was not found.");
}

createRoot(rootElement).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
