
// Imports
import { createRequire } from "module";
const require = createRequire(import.meta.url);
import path, { parse } from 'path';
import { fileURLToPath } from 'url';
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

import { HttpAgent, Actor } from "@dfinity/agent";
import { idlFactory } from "../declarations/research_ai_simple_backend/research_ai_simple_backend.did.js";
const jsonId = require("../../local/canister_ids.json");

const express = require('express');
const app = express();
const bodyParser = require('body-parser');
const cors = require("cors");

// Static files
app.use(express.static('public'));
app.use('/css', express.static(__dirname + 'public/css'));
app.use('/js', express.static(__dirname + 'public/js'));
app.use('/img', express.static(__dirname + 'public/img'));

// Set views
app.set('views', './views');
app.set('view engine', 'ejs');

app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }))

const setup = async () => {
  const agent = new HttpAgent({
    host: "http://127.0.0.1:4943",
  });

  const actor = Actor.createActor(idlFactory, {
    agent,
    canisterId: jsonId.research_ai_simple_backend.local,
  });


  app.post("/submit", async (req, res) => {
    const { title, abstract_body } = req.body;
    await actor.submit_research(title, abstract_body);
    res.send({ ok: true });
  });

  app.post("/submit-query", async (req, res) => {
    const query = req.body.query;
    const result = actor.agent_query_groq({
      prompt: query,
      agent_id: "556",
      store_key: "hlgsbfg_dfydgufihd"
    })

    console.log(result);
  });

  app.get("/search", async (req, res) => {
    const tag = req.query.tag;
    const results = await actor.search_by_tag(tag);
    res.json(results);
  });

  app.get("", async (req, res) => {
    res.render('index', { text: 'This is sparta' });
  });

  app.listen(3000, () => {
    console.log("Server running at http://localhost:3000");
  });
};


setup();
