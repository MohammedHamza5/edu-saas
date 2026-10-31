const fs = require('fs');
const path = require('path');

const routerPath = path.join(__dirname, '..', 'lib', 'core', 'router', 'app_router.dart');
let content = fs.readFileSync(routerPath, 'utf8');

function unwrapDeferred(src) {
  let result = '';
  let i = 0;
  while (i < src.length) {
    const defIdx = src.indexOf('DeferredWidget(', i);
    if (defIdx === -1) {
      result += src.substring(i);
      break;
    }
    result += src.substring(i, defIdx);

    // Find the matching closing paren for DeferredWidget(
    let depth = 0;
    let endIdx = -1;
    for (let j = defIdx + 'DeferredWidget'.length; j < src.length; j++) {
      if (src[j] === '(') depth++;
      else if (src[j] === ')') {
        depth--;
        if (depth === 0) {
          endIdx = j;
          break;
        }
      }
    }

    if (endIdx === -1) {
      throw new Error('Unmatched paren in DeferredWidget at ' + defIdx);
    }

    const block = src.substring(defIdx, endIdx + 1);
    // Find `builder: () =>`
    const builderMatch = block.match(/builder:\s*(?:\(\)\s*(?:async\s*)?=>|(?:\([^)]*\)\s*(?:async\s*)?=>))\s*/);
    if (!builderMatch) {
      throw new Error('Could not find builder in: ' + block);
    }

    const builderStart = builderMatch.index + builderMatch[0].length;
    // The expression inside builder ends before the closing paren of DeferredWidget, trimming trailing commas/whitespace
    let expr = block.substring(builderStart, block.length - 1).trim();
    if (expr.endsWith(',')) {
      expr = expr.substring(0, expr.length - 1).trim();
    }

    result += expr;
    i = endIdx + 1;
  }
  return result;
}

const newContent = unwrapDeferred(content);
fs.writeFileSync(routerPath, newContent, 'utf8');
console.log('Successfully unwrapped all DeferredWidget instances!');
