#!/usr/bin/env node
/*
 * Pre-apply the RDS AI Decoder's tx_search.js patch at build time.
 *
 * The RDS AI Decoder plugin patches server/tx_search.js at runtime to add the
 * AI override hook. That patch only takes effect after a restart, which made
 * the first boot of a fresh container need an extra restart. Applying the same
 * change at build time removes that restart and keeps first boot deterministic.
 *
 * This mirrors the patcher shipped with RDS AI Decoder 3.3b. CI runs the same
 * script with --check, so a plugin update that changes the signatures fails the
 * build instead of silently skipping the patch.
 *
 * Usage: node patch-rds-txsearch.js [APP_ROOT] [--check]
 */
'use strict';

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const checkOnly = args.includes('--check');
const appRoot = args.find((arg) => !arg.startsWith('--')) || '/opt/fm-dx-webserver';
const file = path.join(appRoot, 'server', 'tx_search.js');

const AI_VAR = 'let aiOverride = null;';
const FETCH_SIGNATURE = 'async function fetchTx(freq, piCode, rdsPs) {';
const OVERRIDE_LOGIC = `
    // --- AI DECODER OVERRIDE LOGIC ---
    if (aiOverride && aiOverride.pi === piCode.toUpperCase() && aiOverride.fmdx) {
        return Promise.resolve({
            station: aiOverride.fmdx,
            pol: aiOverride.refPol || '',
            erp: aiOverride.refErp ?? '?',
            city: aiOverride.refTxName || '',
            itu: aiOverride.itu || '',
            distance: aiOverride.refDistKm !== null && aiOverride.refDistKm !== undefined ? aiOverride.refDistKm.toFixed(0) : '',
            azimuth: aiOverride.refAzimuth !== null && aiOverride.refAzimuth !== undefined ? aiOverride.refAzimuth.toFixed(0) : '',
            id: aiOverride.id || '',
            pi: piCode.toUpperCase(),
            foundStation: true,
            reg: false,
            score: 100,
            others: []
        });
    }
    // ---------------------------------`;
const EXPORTS_SIGNATURE = 'module.exports = {';

function fail(message) {
    console.error(`[patch-rds-txsearch] ${message}`);
    process.exit(1);
}

if (!fs.existsSync(file)) fail(`not found: ${file}`);
let content = fs.readFileSync(file, 'utf8');

if (content.includes('setAiOverride')) {
    console.log('[patch-rds-txsearch] tx_search.js already patched');
    process.exit(0);
}

if (checkOnly) fail('tx_search.js is not patched');

if (!content.includes(AI_VAR)) {
    const requireLine = "const consoleCmd = require('./console');";
    if (!content.includes(requireLine)) fail(`missing signature: ${requireLine}`);
    content = content.replace(
        requireLine,
        `${requireLine}\n\n// --- AI DECODER OVERRIDE VARIABLE ---\n${AI_VAR}\n// ------------------------------------`
    );
}

if (!content.includes(FETCH_SIGNATURE)) fail(`missing signature: ${FETCH_SIGNATURE}`);
content = content.replace(FETCH_SIGNATURE, FETCH_SIGNATURE + OVERRIDE_LOGIC);

if (!content.includes(EXPORTS_SIGNATURE)) fail(`missing signature: ${EXPORTS_SIGNATURE}`);
content = content.replace(
    EXPORTS_SIGNATURE,
    "module.exports = {\n    setAiOverride: (data) => { aiOverride = data; },"
);

if (!content.includes('setAiOverride')) fail('patch verification failed');
fs.writeFileSync(file, content, 'utf8');
console.log('[patch-rds-txsearch] tx_search.js patched for AI override');
