#!/usr/bin/env node
// mcp-autorestart — reload dotfiles MCP servers when their source changes.
//
// ZCode keeps one stdio MCP server process per open session and never reloads
// a changed script, but it does respawn a dead server on the next tool call.
// Reload therefore only takes a kill: whenever a ~/dotfiles/bin/mcp-* file
// changes, this watcher SIGTERMs every dotfiles MCP server; the next tool
// call in each session spawns the new code.
//
// Runs as the launchd agent com.morr.mcp-autorestart (RunAtLoad, KeepAlive),
// logging to ~/.local/state/mcp-autorestart.log.

import { watch } from 'node:fs';
import { execFile } from 'node:child_process';
import { homedir } from 'node:os';
import { join } from 'node:path';

const BIN_DIR = join(homedir(), 'dotfiles/bin');
const SERVER_PREFIX = `${homedir()}/dotfiles/bin/mcp-`;
const DEBOUNCE_MS = 200;

const log = (line) => console.log(`${new Date().toISOString()} ${line}`);

function killServers() {
  // -f matches full argv, so a shell or grep whose arguments merely mention
  // the pattern shows up too — kill only processes whose command IS the
  // server: "node <dotfiles>/bin/mcp-*" or the executable itself.
  execFile('pgrep', ['-fl', 'dotfiles/bin/mcp-'], (err, out) => {
    if (err && err.code !== 1) return log(`pgrep failed: ${err.message}`);
    for (const line of out.trim().split('\n').filter(Boolean)) {
      const space = line.indexOf(' ');
      const pid = Number(line.slice(0, space));
      const argv = line.slice(space + 1).split(' ');
      if (pid === process.pid) continue;
      const isNode = /\/node$/.test(argv[0]) && argv[1]?.startsWith(SERVER_PREFIX);
      const isDirect = argv[0].startsWith(SERVER_PREFIX);
      if (!isNode && !isDirect) continue;
      try {
        process.kill(pid, 'SIGTERM');
        log(`killed ${pid} (${argv.join(' ')}) — respawns on next tool call`);
      } catch {
        // already gone
      }
    }
  });
}

let timer = null;
watch(BIN_DIR, (_event, filename) => {
  if (!filename || !filename.startsWith('mcp-')) return;
  clearTimeout(timer);
  timer = setTimeout(killServers, DEBOUNCE_MS);
});
log(`watching ${BIN_DIR}/mcp-*`);
