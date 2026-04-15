import http from 'http';
import fs from 'fs';
import path from 'path';

const PORT = 4300;
const DIR = new URL('.', import.meta.url).pathname;

http.createServer((req, res) => {
  const file = path.join(DIR, req.url === '/' ? 'index.html' : req.url);
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end('Not found'); return; }
    const ext = path.extname(file);
    const ct = ext === '.html' ? 'text/html' : ext === '.css' ? 'text/css' : 'text/plain';
    res.writeHead(200, { 'Content-Type': ct });
    res.end(data);
  });
}).listen(PORT, () => console.log(`Serving on http://localhost:${PORT}`));
