import express from "express";
import cors from "cors";

import taskRoutes from "./routes.js";

const app = express();
app.use(cors());
app.use(express.json());
