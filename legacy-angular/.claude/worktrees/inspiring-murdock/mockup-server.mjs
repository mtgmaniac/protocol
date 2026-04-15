import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const PORT = 4300;
const __dirname = path.dirname(fileURLToPath(import.meta.url));

http.createServer((req, res) => {
  const file = path.join(__dirname, req.url === '/' ? 'mockup.html' : req.url);
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end('Not found'); return; }
    const ext = path.extname(file);
    const ct = ext === '.html' ? 'text/html' : 'text/plain';
    res.writeHead(200, { 'Content-Type': ct });
    res.end(data);
  });
}).listen(PORT, () => console.log('Serving on http://localhost:' + PORT));
