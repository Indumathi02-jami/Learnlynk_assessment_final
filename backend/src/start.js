// Load dotenv BEFORE anything else
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({
  path: path.join(__dirname, ".env"),
});

// DYNAMIC IMPORT (prevents early execution)
const start = async () => {
  await import("./server.js");
};

start();
