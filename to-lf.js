/**
 * Convert all files in the current directory and subdirectories to LF line endings.
 *
 * NOTE: This may not be needed anymore due to .gitattributes. We'll keep it around just in case.
 *       As such, this script isn't documented.
 *
 * Usage:
 * node to-lf.js
 */

import fs from 'fs';
import path from 'path';

const directory = process.cwd(); // The root directory to start from
const filepath = process.argv[2] ?? '';

function convertToLF(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  if (content.includes('\r\n')) {
    const normalized = content.replace(/\r\n/g, '\n');
    fs.writeFileSync(filePath, normalized, 'utf8');
    console.log(`Converted to LF: ${filePath}`);
  }
}

function processDirectory(dir) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const filePath = path.join(dir, file);
    if (filePath[0] === '.') console.log(filePath);
    if (filePath.startsWith('node_modules' + path.sep) || filePath.startsWith('.git' + path.sep)) {
      continue;
    }
    const stats = fs.statSync(filePath);
    if (stats.isDirectory()) {
      processDirectory(filePath); // Recurse into subdirectories
    } else {
      convertToLF(filePath); // Convert file line endings
    }
  }
}

if (filepath) {
  convertToLF(filepath);
} else {
  processDirectory(directory);
}

console.log('Conversion complete');
