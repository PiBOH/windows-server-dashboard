/* ===================== i18n ===================== */
var SYSLANG = "__SYSLANG__";
var VERSION = "__VERSION__";
var INTERVAL = "__INTERVAL__";
var LANGS = [];          /* [{code,native,english,dir}] */
var STR = {};            /* dizionario corrente */
var CURLANG = "en-US";

/* English text for the strings the language files do not carry (yet): T()
   answers with this instead of the bare key name, so a language installed
   later never shows an identifier to the user. A translation always wins. */
var EN = {
  about_open:      'About this dashboard',
  about_title:     'About',
  about_role:      'Developer of this dashboard',
  about_portfolio: 'Portfolio',
  about_releases:  'Releases',
  about_changelog: 'Changelog',
  about_live:      'read live from GitHub every time this panel opens',
  about_reload:    'Reload',
  about_close:     'Close',
  about_loading:   'Reading the changelog from GitHub...',
  about_offline:   'The changelog could not be read from GitHub: this panel needs internet access from this browser.',
  about_empty:     'The changelog is empty.',
  about_src:       'read live from github.com/PiBOH/windows-server-dashboard',
  /* the "?" next to a missing temperature and the panel behind it */
  temp_help_open:  'Why is the CPU temperature missing?',
  temp_help_title: 'Why the CPU temperature is missing',
  temp_help_why:   'No source answered, so the dashboard has no number to show. It does not measure the temperature itself and it starts nothing: it reads what a program that does measure it publishes. Install one of these and leave it running - no add-on, no plug-in, nothing to install inside the dashboard:',
  temp_help_ct_hint:     'the lightest, one reading per core',
  temp_help_lhm_hint:    'successor of Open Hardware Monitor',
  temp_help_ohm_hint:    'the older, still used',
  temp_help_hwinfo_hint: 'wants its WMI provider switched on',
  temp_help_bios:  'Do not count on the BIOS or on ACPI: the BIOS almost never exposes the temperature of the CPU, and the ACPI thermal zone is a zone of the motherboard - often the chassis - not the processor. Those programs read the CPU itself, which is why they are the way that works.',
  temp_help_running: 'If one of them already runs and the reading is still missing, look at the ServerDashboard log on the server: it names every source it tried and the ones it found. Core Temp running on the desktop is not always visible to a dashboard running as a service: switch on "enable global shared memory" in Core Temp > Options > Advanced, or enable logging in Core Temp, so the dashboard can read its log file.',
  temp_help_close: 'Close',
  /* the right-click menu of the process and service rows, and its Properties
     panel */
  ctx_search:      'Search the web',
  ctx_props:       'Properties',
  ctx_copy_name:   'Copy name',
  ctx_copy_pid:    'Copy PID',
  ctx_copied_name: 'Name copied',
  ctx_copied_pid:  'PID copied',
  ctx_copy_failed: 'Could not copy: select the text in the Properties panel instead',
  prop_path:       'Path',
  close:           'Close',
  srv_refresh_both: 'how often the server samples and this page refreshes'
};

function T(k){
  if (STR[k] !== undefined && STR[k] !== "") return STR[k];
  return (EN[k] !== undefined) ? EN[k] : k;
}

function pickLang(){
  var saved = LOCAL.lang;
  var codes = LANGS.map(function(l){ return l.code; });
  if (saved && codes.indexOf(saved) >= 0) return saved;
  if (codes.indexOf(SYSLANG) >= 0) return SYSLANG;                 /* es. it-IT */
  var pre = (SYSLANG || 'en').split('-')[0].toLowerCase();         /* es. it    */
  for (var i = 0; i < LANGS.length; i++){
    if (LANGS[i].code.split('-')[0].toLowerCase() === pre) return LANGS[i].code;
  }
  return codes.indexOf('en-US') >= 0 ? 'en-US' : (codes[0] || 'en-US');
}

function applyStatic(){
  try { DECSEP = (1.1).toLocaleString(CURLANG).replace(/1/g, '') || '.'; } catch (e) { DECSEP = '.'; }
  var els = document.querySelectorAll('[data-i18n]');
  for (var i = 0; i < els.length; i++){ els[i].textContent = T(els[i].getAttribute('data-i18n')); }
  var ph = document.querySelectorAll('[data-i18n-ph]');
  for (var j = 0; j < ph.length; j++){ ph[j].placeholder = T(ph[j].getAttribute('data-i18n-ph')); }
  var ti = document.querySelectorAll('[data-i18n-title]');
  for (var m = 0; m < ti.length; m++){ ti[m].title = T(ti[m].getAttribute('data-i18n-title')); }
  document.title = (document.getElementById('host').textContent || '') + ' - ' + T('app_title');
  var cur = null;
  for (var k = 0; k < LANGS.length; k++){ if (LANGS[k].code === CURLANG) cur = LANGS[k]; }
  if (cur){
    document.getElementById('curlang').textContent = cur.native + ' (' + cur.english + ')';
    document.documentElement.dir = cur.dir || 'ltr';
    document.documentElement.lang = cur.code;
  }
  document.getElementById('themelabel').textContent = (THEME === 'dark') ? T('theme_light') : T('theme_dark');
  document.getElementById('setlabel').textContent = T('settings');
  paintConn();
  if (LANGS.length) { fillRates(); }
  paintHeaders('tproc'); paintHeaders('tsvc'); paintHeaders('tev');
}

function parseLangXml(txt){
  var d = new DOMParser().parseFromString(txt, 'text/xml');
  var out = {}, n = d.getElementsByTagName('string');
  for (var i = 0; i < n.length; i++){ out[n[i].getAttribute('key')] = n[i].textContent; }
  return out;
}

function setLang(code, save){
  return fetchLang(code).then(function(dict){
    STR = dict; CURLANG = code;
    if (save){ LOCAL.lang = code; saveLocal(); }
    applyStatic(); buildLangGrid();
    forceRepaint = true;
    if (lastData) render(lastData);
    forceRepaint = false;
    drawProcs(); drawSvcs(); drawEvents();
  });
}

function fetchLangList(){
  return fetch('api/languages?v=' + VERSION).then(function(r){ return r.json(); });
}

function fetchLang(code){
  return fetch('lang/' + code + '.xml?v=' + VERSION).then(function(r){ return r.text(); }).then(parseLangXml);
}

function buildLangGrid(){
  document.getElementById('langgrid').innerHTML = LANGS.map(function(l){
    return '<button class="langitem' + (l.code === CURLANG ? ' cur' : '') + '" data-code="' + l.code + '">' +
           '<div>' + l.native + '</div><div class="en">' + l.english + ' &bull; ' + l.code + '</div></button>';
  }).join('');
  var items = document.querySelectorAll('.langitem');
  for (var i = 0; i < items.length; i++){
    items[i].onclick = function(){ setLang(this.getAttribute('data-code'), true); closeLang(); };
  }
}

/* ===================== settings =====================
   Browser side  (localStorage key "dashsettings"): theme, language and the visitor's
   own refresh interval. Those are personal and never leave the browser.
   Server side   (settings.txt next to the script): default refresh interval, idle
   sampling, visible sections, logging, automatic updates. The panel writes them back
   into settings.txt: with no password set whoever is looking at the page can save
   them, with a password only after typing it (partial) or logging in (total).
   When no settings are found the defaults apply: dark theme, Windows display language,
   0.5 second refresh, no sampling while nobody is connected, every section visible.  */
var SECTIONS = ['cpu','cpu_trend','ram','ram_trend','network','net_adapters','ip_config',
                'disks','os','processes','services','events'];
var RATES = [0.5,1,2,5,10,15,30,60,300];
var SRV = { refreshSeconds: 0.5, idleSeconds: 0, autoUpdate: true, logging: false,
            sections: {}, passwordProtected: false, passwordMode: '' };
var SRVPWD = null;   /* password typed in the unlock box (partial mode) */
/* decimal separator of the chosen language, used for values like 0,5 */
var DECSEP = ',';   /* server settings */
var LOCAL = { theme: 'dark', lang: null, refresh: null };   /* refresh: null = use the server default */                         /* browser settings */

function loadLocal(){
  try {
    var raw = null;
    try { raw = localStorage.getItem('dashsettings'); } catch(e){ raw = null; }
    if (!raw) { try { var cm = document.cookie.match(/(?:^|; )dashprefs=([^;]*)/);
                      if (cm) raw = decodeURIComponent(cm[1]); } catch(e){ } }
    if (raw) { var o = JSON.parse(raw); if (o && typeof o === 'object') {
      if (o.theme) LOCAL.theme = o.theme;
      if (o.lang)  LOCAL.lang  = o.lang;
      if (o.refresh != null && !isNaN(parseFloat(o.refresh))) LOCAL.refresh = parseFloat(o.refresh);
    } }
  } catch(e){ }
  return LOCAL;
}
function saveLocal(){
  /* The choice is written to localStorage AND to a cookie: a browser that
     refuses localStorage (privacy mode, storage policy) would otherwise drop
     the personal refresh interval silently, and the next visit would show the
     server default again with no explanation. */
  var json = JSON.stringify(LOCAL);
  try { localStorage.setItem('dashsettings', json); } catch(e){ }
  try { document.cookie = 'dashprefs=' + encodeURIComponent(json) + ';path=/;max-age=31536000'; } catch(e){ }
}
function storageOK(){
  /* true when at least one of the two stores accepts a write: the settings
     panel says so instead of losing the choice at the next visit */
  try { localStorage.setItem('dashtest','1'); localStorage.removeItem('dashtest'); return true; } catch(e){ }
  try { document.cookie = 'dashtest=1;path=/;max-age=60';
        var ok = /(?:^|; )dashtest=1/.test(document.cookie);
        document.cookie = 'dashtest=;path=/;max-age=0'; return ok; } catch(e){ return false; }
}

function loadServer(){
  /* If the server has no settings file (or it cannot be read) the built-in
     defaults below are used, so the panel always opens. */
  return fetch('api/settings?_=' + Date.now()).then(function(r){ return r.json(); })
    .then(function(o){
      if (o && o.refreshSeconds) { SRV = o; }
      if (!SRV.sections) { SRV.sections = {}; }
      if (!SRV.passwordProtected) { SRV.passwordProtected = false; }
      if (!SRV.passwordMode) { SRV.passwordMode = ''; }
      return SRV;
    })
    .catch(function(){ if (!SRV.sections) SRV.sections = {}; return SRV; });
}
/* The server options live in settings.txt, and the panel is where they are
   written:
   - no password: the panel is open to whoever is watching the page, so Save
     writes settings.txt from the browser - no need to edit the file by hand;
   - total mode: the browser already authenticated with the password (Basic
     auth), so saving posts the options directly;
   - partial mode: the password given in the popup (see below) travels in
     the body and the server refuses the change if it is wrong. */
function serverEditable(){
  if (!SRV.passwordProtected) { return true; }
  if (SRV.passwordMode !== 'partial') { return true; }
  return (SRVPWD !== null);
}
function saveServer(){
  var secs = {};
  var boxes = document.querySelectorAll('#setsections input[data-sec-key]');
  for (var i = 0; i < boxes.length; i++) {
    secs['show_' + boxes[i].getAttribute('data-sec-key')] = boxes[i].checked;
  }
  var payload = {
    settings: {
      refresh_seconds: parseFloat(document.getElementById('setsrvrate').value),
      auto_update: document.getElementById('setautoupd').checked,
      logging: document.getElementById('setlogging').checked
    }
  };
  for (var k in secs) { payload.settings[k] = secs[k]; }
  if (SRV.passwordMode === 'partial') { payload.password = SRVPWD; }
  return fetch('api/settings', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    }).then(function(r){
      if (r.status === 403) { throw new Error('wrong password'); }
      if (!r.ok) { throw new Error('http ' + r.status); }
      return r.json();
    }).then(function(o){
      /* the answer says what was APPLIED, not the new settings: the values
         just sent are the ones settings.txt holds now, so the interval this
         page uses follows them at once instead of at the next reload */
      if (o && o.applied && o.applied.indexOf('refresh_seconds') >= 0) {
        SRV.refreshSeconds = parseFloat(document.getElementById('setsrvrate').value);
      }
      return SRV;
    });
}

/* ================= PASSWORD POPUP (partial mode) ===================== */
/* The options look normal in the panel: the password is asked by a small
   popup only at the moment somebody clicks one of them, never before. */
var PWBUSY = false;
var pwLastTarget = null;

function pwLocked(){
  return SRV.passwordProtected && SRV.passwordMode === 'partial' && SRVPWD === null;
}
function pwRealTarget(t){
  /* from the clicked element (label, span, ...) to the real control */
  try {
    var el = t;
    while (el && el !== document) {
      if (el.tagName === 'LABEL' && el.control) { return el.control; }
      if (el.tagName === 'INPUT' || el.tagName === 'SELECT') { return el; }
      el = el.parentNode;
    }
  } catch(e){ }
  return t;
}
function verifyServerPassword(pw){
  /* asks the server WITHOUT changing anything: an empty list of settings
     is a pure password check (the server answers 200 or 403) */
  return fetch('api/settings', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ password: pw, settings: {} })
    }).then(function(r){
      if (r.status === 403) { throw new Error('wrong password'); }
      if (!r.ok) { throw new Error('http ' + r.status); }
      return r.json();
    });
}
function openPwPopup(target){
  pwLastTarget = target || null;
  var inp = document.getElementById('pwinput');
  var msg = document.getElementById('pwmsg');
  if (inp) { inp.value = ''; }
  if (msg) { msg.textContent = ''; }
  document.getElementById('pwmodal').className = 'modal on';
  if (inp) { setTimeout(function(){ try { inp.focus(); } catch(e){ } }, 60); }
}
function closePwPopup(){
  document.getElementById('pwmodal').className = 'modal';
}
function submitPwPopup(){
  if (PWBUSY) { return; }
  var inp = document.getElementById('pwinput');
  var msg = document.getElementById('pwmsg');
  var v = inp ? inp.value : '';
  if (!v) { return; }
  PWBUSY = true;
  verifyServerPassword(v).then(function(){
    SRVPWD = v;                 /* in memory only: no form, no storage */
    PWBUSY = false;
    closePwPopup();
    fillSettings();
    /* complete the click that opened the popup */
    var t = pwLastTarget;
    if (t && t.tagName === 'INPUT' &&
        (t.type === 'checkbox' || t.type === 'radio')) { t.click(); }
    else if (t && t.focus) { try { t.focus(); } catch(e){ } }
  }).catch(function(){
    PWBUSY = false;
    if (msg) { msg.textContent = T('wrong_password'); }
    if (inp) { inp.value = ''; try { inp.focus(); } catch(e){ } }
  });
}
function pwUpgradeMasking(){
  /* The password field must NEVER be offered for saving by a browser -
     Chrome, Edge, Safari, Firefox, desktop and mobile - nor by password
     manager add-ons. Where the CSS property -webkit-text-security exists
     (every Chromium and WebKit browser) the field becomes a plain TEXT
     input that only looks masked: no password semantics, so no save
     prompt and no fill icon, ever. Where it does not exist (Firefox) it
     stays a password field, but it belongs to no form, nothing is ever
     submitted and autocomplete is set to new-password. */
  var inp = document.getElementById('pwinput');
  if (!inp) { return; }
  try {
    var probe = document.createElement('input');
    probe.style.webkitTextSecurity = 'disc';
    document.body.appendChild(probe);
    var ok = (getComputedStyle(probe).webkitTextSecurity === 'disc');
    document.body.removeChild(probe);
    if (ok) {
      inp.type = 'text';
      inp.className = 'pwinput pwmasked';
    }
  } catch(e){ }
}
pwUpgradeMasking();

function applySections(){
  var els = document.querySelectorAll('[data-sec]');
  for (var i = 0; i < els.length; i++){
    var k = els[i].getAttribute('data-sec');
    els[i].style.display = (SRV.sections && SRV.sections[k] === false) ? 'none' : '';
  }
}
/* The interval each visitor actually uses: their own choice if they made one,
   otherwise the default configured on the server in settings.txt. It only
   changes how often THIS browser asks for data - it does not touch the server
   settings, and it does not affect anybody else. */
function effRate(){
  return (LOCAL.refresh != null) ? LOCAL.refresh : SRV.refreshSeconds;
}
function applyRate(){
  clearInterval(timer);
  var sel = document.getElementById('rate');
  if (sel) sel.value = (LOCAL.refresh != null) ? String(LOCAL.refresh) : '';
  var s2 = document.getElementById('setrate');
  if (s2) s2.value = (LOCAL.refresh != null) ? String(LOCAL.refresh) : '';
  if (document.hidden) return;         /* nobody is watching: do not poll at all */
  timer = setInterval(load, Math.max(0.5, effRate()) * 1000);
}
function rateLabel(sec){
  if (sec >= 60) { var m = sec / 60; return m + ' ' + ((m === 1) ? T('minute') : T('minutes')); }
  if (sec < 1) return String(sec).replace('.', DECSEP) + ' ' + T('seconds');
  return sec + ' ' + ((sec === 1) ? T('second') : T('seconds'));
}
function fillRates(){
  var html = '<option value="">' + T('server_default') + ' (' + rateLabel(SRV.refreshSeconds) + ')</option>' +
             RATES.map(function(v){ return '<option value="'+v+'">'+rateLabel(v)+'</option>'; }).join('');
  var cur = (LOCAL.refresh != null) ? String(LOCAL.refresh) : '';
  ['rate','setrate'].forEach(function(id){
    var el = document.getElementById(id);
    if (el) { el.innerHTML = html; el.value = cur; }
  });
}
function fillSrvRate(){
  /* the server default refresh, as proposed to every new visitor */
  var cur = String(SRV.refreshSeconds);
  var html = RATES.map(function(v){
    return '<option value="'+v+'"'+(String(v)===cur?' selected':'')+'>'+rateLabel(v)+'</option>';
  }).join('');
  if (RATES.indexOf(SRV.refreshSeconds) < 0) {
    html = '<option value="'+cur+'" selected>'+rateLabel(SRV.refreshSeconds)+'</option>' + html;
  }
  var el = document.getElementById('setsrvrate');
  if (el) { el.innerHTML = html; el.disabled = false; }
}
/* The refresh choice of this browser and the one of the server ask the same
   question, and with no password there is nothing to protect in settings.txt:
   they become one. The server row stays (it is the one that writes the file)
   and the personal row leaves the DOM - kept aside, not hidden behind a
   style, so no second field is left orphaned. With a password the two are
   different things again and the row comes back. */
var PERSONAL_ROW = null;
function personalRow(){
  return PERSONAL_ROW || (PERSONAL_ROW = document.getElementById('prow'));
}
function syncRefreshRows(){
  var row = personalRow(), srv = document.getElementById('srvrow');
  var merged = !SRV.passwordProtected;
  if (merged && row && row.parentNode) { row.parentNode.removeChild(row); }
  if (!merged && row && !row.parentNode) {
    srv.parentNode.insertBefore(row, srv);
    fillRates();                       /* its options may be stale in here */
  }
  var both = document.getElementById('srvbot');
  if (both) { both.style.display = merged ? 'inline' : 'none'; }
}

function fillSettings(){
  syncRefreshRows();
  document.getElementById('settheme').value = THEME;
  document.getElementById('setlang').innerHTML = LANGS.map(function(l){
    return '<option value="'+l.code+'"'+(l.code===CURLANG?' selected':'')+'>'+l.native+' ('+l.english+')</option>';
  }).join('');
  var row = personalRow(), ps = row ? row.querySelector('select') : null;
  if (ps) { ps.value = (LOCAL.refresh != null) ? String(LOCAL.refresh) : ''; }
  var sw = document.getElementById('storwarn');
  if (sw) { sw.style.display = storageOK() ? 'none' : 'block'; }
  var ed = serverEditable();
  var prot = !!SRV.passwordProtected;
  /* status note only: unlocked / password needed. With no password there is
     nothing to unlock: the options are editable and Save writes settings.txt
     from the page. In partial mode the options look NORMAL - the password
     popup appears only when one of them is clicked, never before - so the
     controls stay enabled and the first click is intercepted until the
     password is given; total mode is already unlocked by the login that
     opened the page. */
  var note = document.getElementById('srvnote');
  if (note) {
    note.className = 'srvnote';
    if (!prot) { note.textContent = T('srv_unlocked'); note.className = 'srvnote ok'; }
    else if (ed) { note.textContent = T('srv_unlocked'); note.className = 'srvnote ok'; }
    else { note.textContent = T('srv_locked'); }
  }
  fillSrvRate();
  document.getElementById('setsections').innerHTML = SECTIONS.map(function(k){
    var on = !(SRV.sections && SRV.sections[k] === false);
    return '<label class="ro"><input type="checkbox"'+
           ' data-sec-key="'+k+'"'+(on?' checked':'')+'> <span>'+T(k)+'</span></label>';
  }).join('');
  var lg = document.getElementById('setlogging');
  var au = document.getElementById('setautoupd');
  if (lg) { lg.checked = !!SRV.logging; lg.disabled = false; }
  if (au) { au.checked = !!SRV.autoUpdate; au.disabled = false; }
  document.getElementById('setmsg').textContent = '';
}
function openLang(){ buildLangGrid(); document.getElementById('langmodal').className = 'modal on'; }
function closeLang(){ document.getElementById('langmodal').className = 'modal'; }
function openSettings(){ fillSettings(); document.getElementById('setmodal').className = 'modal on'; }
function closeSettings(){ document.getElementById('setmodal').className = 'modal'; }

/* ===================== About =====================
   The changelog is not shipped in the package and not stored anywhere: it is
   read from GitHub every time this panel opens, with a cache key that is never
   the same twice, so the browser never answers from its own cache. The answer
   is escaped before it reaches the page. */
var CHANGELOG_URL = 'https://raw.githubusercontent.com/PiBOH/windows-server-dashboard/main/Changelog/CHANGELOG.md';

function renderChangelog(md){
  var lines = String(md).split(/\r?\n/), out = [], seen = false;
  var verRe = /^\s*(\d+\.\d+\.\d+)\s*[-\u2013]\s*(\d{4}-\d{2}-\d{2})/;
  var catRe = /^\s*(Added|Fixed|Changed|Removed|Deprecated|Security)\s*:/;
  for (var i = 0; i < lines.length; i++){
    var L = lines[i];
    var v = L.match(verRe);
    if (v){
      seen = true;
      out.push('<div class="ver">v' + esc(v[1]) + ' <span class="d">' + esc(v[2]) + '</span></div>');
      continue;
    }
    if (!seen) continue;                       /* the preamble is not the log */
    if (!L.trim() || /^\s*={5,}\s*$/.test(L)) continue;
    var c = L.match(catRe);
    if (c){ out.push('<div class="cl"><span class="cat">' + esc(c[1]) + '</span>' + esc(L.slice(c[0].length)) + '</div>'); }
    else  { out.push('<div class="cl plain">' + esc(L.replace(/^\s+/, '')) + '</div>'); }
  }
  return out.join('');
}

var CHANGELOG_REQ = 0;

function loadAboutChangelog(){
  var box = document.getElementById('aboutcl');
  var src = document.getElementById('aboutsrc');
  /* reopening the panel or pressing Reload starts a new request: an answer
     that arrives late must not overwrite a newer one */
  var req = ++CHANGELOG_REQ;
  box.innerHTML = '<div class="cl plain">' + esc(T('about_loading')) + '</div>';
  src.textContent = '';
  /* cache: 'no-store' and a key that never repeats: the answer must come from
     GitHub, not from a copy some layer kept */
  var url = CHANGELOG_URL + '?sb=' + Date.now() + '-' + Math.random().toString(36).slice(2);
  return fetch(url, { cache: 'no-store', credentials: 'omit', redirect: 'follow' })
    .then(function(r){ if (!r.ok) throw new Error('HTTP ' + r.status); return r.text(); })
    .then(function(txt){
      if (req !== CHANGELOG_REQ) return;
      box.innerHTML = renderChangelog(txt) || '<div class="cl plain">' + esc(T('about_empty')) + '</div>';
      box.scrollTop = 0;
      src.textContent = T('about_src') + ' \u00b7 ' + new Date().toLocaleTimeString();
    })
    .catch(function(e){
      if (req !== CHANGELOG_REQ) return;
      box.innerHTML = '<div class="cl crit">' + esc(T('about_offline')) + '</div>';
      src.textContent = (e && e.message) ? e.message : 'network';
    });
}

/* the one way in: the footer line, and the Reload button inside the panel,
   both come through here, so opening the panel and reading the changelog can
   never drift apart */
function openAbout(){
  document.getElementById('aboutver').textContent = VERSION;
  document.getElementById('aboutmodal').className = 'modal on';
  loadAboutChangelog();
}
function closeAbout(){ document.getElementById('aboutmodal').className = 'modal'; }

/* the same one-way-in rule as the About panel: the "?" and every way out of
   the panel come through these two, so opening and closing cannot drift apart */
function openTempHelp(){ document.getElementById('tempmodal').className = 'modal on'; }
function closeTempHelp(){ document.getElementById('tempmodal').className = 'modal'; }

/* ===================== right-click menu ===================== */
/* The process and service tables open a menu on the right button. It works from
   the data of the row it was opened on, copied when it opens, so the table
   redrawing under it every few seconds cannot change what the entries mean.
   Nothing here is destructive on purpose: the dashboard cannot kill a process
   nor stop a service, so it does not offer to.
   Only those rows suppress the menu of the browser; everywhere else it stays. */
var ctxData = null;     /* { kind:'proc'|'svc', o:{...} } captured at open */
var ctxTimer = null;    /* the confirmation shown after a copy hides itself */

function ctxItems(){
  var o = ctxData.o, out = [];
  /* a real link, so the middle click and "open in a new tab" work the way
     they do everywhere else: the browser decides how to open the search */
  out.push({ href: 'https://www.google.com/search?q=' + encodeURIComponent(o.Name), label: T('ctx_search') });
  out.push({ fn: openProps, label: T('ctx_props') });
  out.push({ fn: function(){ copyCtx(o.Name, 'ctx_copied_name'); }, label: T('ctx_copy_name') });
  /* a stopped service has no process, so there is no PID worth copying */
  if (o.Pid) { out.push({ fn: function(){ copyCtx(String(o.Pid), 'ctx_copied_pid'); }, label: T('ctx_copy_pid') }); }
  return out;
}

function openCtxMenu(x, y, kind, o){
  closeCtxMenu();
  ctxData = { kind: kind, o: o };
  var m = document.getElementById('ctxmenu');
  var where = (kind === 'svc') ? (o.Display || o.Name) : (o.Desc || o.Name);
  m.innerHTML = '<div class="ctxhint">' + esc(where) + '</div>';
  var items = ctxItems();
  for (var i = 0; i < items.length; i++){
    (function(it){
      var el;
      if (it.href){
        el = document.createElement('a');
        el.href = it.href;
        el.target = '_blank';
        el.rel = 'noopener noreferrer';
      } else {
        el = document.createElement('button');
        el.type = 'button';
        el.onclick = it.fn;
      }
      el.className = 'ctxitem';
      el.setAttribute('role', 'menuitem');
      el.textContent = it.label;
      m.appendChild(el);
    })(items[i]);
  }
  m.className = 'ctxmenu on';
  m.setAttribute('aria-hidden', 'false');
  var pad = 8;
  m.style.left = x + 'px';
  m.style.top  = y + 'px';
  /* measured where it would sit, then pulled back inside the window: both
     happen before the next paint, so it never shows up half outside */
  var r = m.getBoundingClientRect();
  m.style.left = Math.max(pad, Math.min(x, innerWidth  - pad - r.width))  + 'px';
  m.style.top  = Math.max(pad, Math.min(y, innerHeight - pad - r.height)) + 'px';
}

/* the one way out, like the panels: the pointer elsewhere, Escape, a resize, a
   scroll of the tables it belongs to, and the end of its own confirmation */
function closeCtxMenu(){
  if (ctxTimer) { clearTimeout(ctxTimer); ctxTimer = null; }
  ctxData = null;
  var m = document.getElementById('ctxmenu');
  if (m && m.className !== 'ctxmenu'){
    m.className = 'ctxmenu';
    m.setAttribute('aria-hidden', 'true');
    m.innerHTML = '';
  }
}

function copyCtx(txt, okKey){
  function fallback(){
    /* over plain http - which is how this page is reached on a LAN - the
       clipboard API is not available: copy the old way instead */
    try {
      var ta = document.createElement('textarea');
      ta.value = txt;
      ta.setAttribute('readonly', '');
      ta.style.position = 'fixed';
      ta.style.top = '-1000px';
      document.body.appendChild(ta);
      ta.select();
      var ok = document.execCommand('copy');
      document.body.removeChild(ta);
      return ok;
    } catch (e) { return false; }
  }
  function done(ok){
    var m = document.getElementById('ctxmenu');
    if (!m || m.className !== 'ctxmenu on') { return; }
    /* the copy answers in place - the entries become the confirmation - and
       the menu closes on its own. A failed copy says what to do instead. */
    m.innerHTML = '<div class="ctxitem msg">' +
        esc(ok ? (T(okKey) + ': ' + txt) : T('ctx_copy_failed')) + '</div>';
    if (ctxTimer) { clearTimeout(ctxTimer); }
    ctxTimer = setTimeout(closeCtxMenu, ok ? 1400 : 3400);
  }
  if (navigator.clipboard && navigator.clipboard.writeText){
    navigator.clipboard.writeText(txt).then(function(){ done(true); }, function(){ done(fallback()); });
  } else { done(fallback()); }
}

/* the Properties panel: what the dashboard already has about that row, and
   nothing else. /api/stats carries no owner and no start time for a process,
   so none is shown rather than a guess. */
function openProps(){
  var d = ctxData;
  if (!d) { return; }
  var o = d.o, svc = (d.kind === 'svc');
  var rows = svc
    ? [['display_name', o.Display], ['service_name', o.Name],
       ['status', tState(o.State)], ['startup', tMode(o.StartMode)],
       ['pid', o.Pid || '-'], ['account', o.Account || '-'],
       ['prop_path', o.Path || '-']]
    : [['process', o.Name], ['pid', o.Pid], ['cpu_pct', fmt(o.CpuPct)],
       ['ram_mb', fmt(o.RamMB)], ['threads_c', o.Threads],
       ['handles', o.Handles], ['prop_path', o.Path || '-']];
  if (!svc && o.Desc) { rows.splice(1, 0, ['display_name', o.Desc]); }
  document.getElementById('propname').textContent = svc ? (o.Display || o.Name) : (o.Desc || o.Name);
  document.getElementById('propkv').innerHTML = rows.map(function(r){
    return '<b>' + esc(T(r[0])) + '</b><span>' + esc(r[1]) + '</span>';
  }).join('');
  closeCtxMenu();
  document.getElementById('propmodal').className = 'modal on';
}
function closeProps(){ document.getElementById('propmodal').className = 'modal'; }

function applySettings(){
  /* Personal choices are always saved in this browser. The server options are
     posted too when they are editable (no password set, password given, total
     mode): the server itself decides whether the change is accepted. */
  var th = document.getElementById('settheme').value;
  var lg = document.getElementById('setlang').value;
  var row = personalRow(), ps = row ? row.querySelector('select') : null;
  var rv = ps ? ps.value : '';
  LOCAL.theme = th;
  /* with one option only, the choice IS the server one: this browser keeps no
     override of its own, so the page and the engine cannot drift apart */
  LOCAL.refresh = SRV.passwordProtected ? ((rv === '') ? null : parseFloat(rv)) : null;
  saveLocal();
  applyRate();
  applyTheme(th, true);
  var note = document.getElementById('srvnote');
  var p = (lg !== CURLANG) ? setLang(lg, true) : Promise.resolve();
  var q = p.then(function(){
    if (!serverEditable()) { return null; }
    return saveServer().catch(function(){
      if (note) { note.className = 'srvnote crit'; note.textContent = T('wrong_password'); }
      throw new Error('refused');
    });
  });
  return q.then(function(){
    fillRates();
    fillSrvRate();
    applyRate();                       /* the saved interval, from now on */
    document.getElementById('setmsg').textContent = T('saved_ok');
    setTimeout(function(){ var m = document.getElementById('setmsg'); if (m) m.textContent = ''; }, 2500);
  }, function(){ /* refused: the note above already says why */ });
}
function resetSettings(){
  /* resets the personal choices only: dark theme, language of Windows and the
     refresh interval back to the one configured on the server */
  LOCAL.theme = 'dark'; LOCAL.lang = null; LOCAL.refresh = null; saveLocal();
  applyTheme('dark', true);
  applyRate();
  setLang(pickLang(), false).then(function(){ fillRates(); fillSettings(); });
}

/* ===================== theme (dark / light) ===================== */
var THEME = 'dark';
function applyTheme(t, save){
  THEME = (t === 'light') ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', THEME);
  document.getElementById('themeicon').innerHTML = (THEME === 'dark') ? '&#9788;' : '&#9789;';
  document.getElementById('themelabel').textContent = (THEME === 'dark') ? T('theme_light') : T('theme_dark');
  if (save) { LOCAL.theme = THEME; saveLocal(); }
  draw();
}
function initTheme(){ applyTheme(LOCAL.theme || 'dark', false); }
function cssVar(n){
  return (getComputedStyle(document.documentElement).getPropertyValue(n) || '').trim();
}

/* ===================== helpers ===================== */
var hist = [], lastData = null;
function col(v){ return v < 60 ? '#3fb950' : (v < 85 ? '#d29922' : '#f85149'); }
function cls(v){ return v < 60 ? 'ok' : (v < 85 ? 'warn' : 'crit'); }
function esc(s){ return String(s==null?'':s).replace(/[<>&]/g, function(c){return {'<':'&lt;','>':'&gt;','&':'&amp;'}[c];}); }
function fmt(n,d){ return (n==null?0:n).toFixed(d===undefined?1:d); }
function tState(v){ return v === 'Running' ? T('st_running') : (v === 'Stopped' ? T('st_stopped') : v); }
function tMode(v){ return v === 'Auto' ? T('sm_auto') : (v === 'Manual' ? T('sm_manual')
                 : (v === 'Disabled' ? T('sm_disabled') : v)); }

if (!Element.prototype.closest) {
  Element.prototype.closest = function(sel){
    var el = this;
    while (el && el.nodeType === 1) {
      if ((el.matches || el.msMatchesSelector).call(el, sel)) return el;
      el = el.parentElement;
    }
    return null;
  };
}

/* ===================== table sorting ===================== */
var lastProcs = [], lastSvcs = [], lastEvents = [];
/* Signatures of the last painted payload: the process, service, event and disk
   sections are re-rendered only when the server actually sent new data. With a
   1 second refresh this avoids rebuilding hundreds of rows every second, both
   on the browser and (through smaller work) on the server. */
var sig = { proc:'', svc:'', ev:'', disk:'' };
function quickSig(a){
  if (!a || !a.length) return '0';
  var s = a.length + '|';
  for (var i = 0; i < a.length; i += Math.max(1, Math.floor(a.length / 12))) {
    var o = a[i];
    s += (o.Pid || o.Name || o.EventId || o.Model || '') + ':' +
         (o.CpuPct != null ? o.CpuPct : (o.State || o.Time || o.BusyPct || '')) + ';';
  }
  return s;
}
var NUMKEYS = {Pid:1, CpuPct:1, RamMB:1, Threads:1, Handles:1, EventId:1, Level:1};
/* the processes open in name order (A to Z, the friendly name the column
   shows), not by CPU: with two hundred of them a list that moves at every
   refresh is unreadable. Every column can still be clicked, and the choice
   is remembered per browser. */
var DEFSORT = { tproc: {k:'Name', d:1}, tsvc: {k:'State', d:1}, tev: {k:'Time', d:-1} };
var sortState = { tproc: null, tsvc: null, tev: null };

function loadSort(id){
  if (sortState[id]) return sortState[id];
  var st = null;
  try { st = JSON.parse(localStorage.getItem('sort_' + id)); } catch(e){ }
  if (!st || !st.k) { st = { k: DEFSORT[id].k, d: DEFSORT[id].d }; }
  sortState[id] = st; return st;
}
function saveSort(id){ try { localStorage.setItem('sort_' + id, JSON.stringify(sortState[id])); } catch(e){ } }
function sortRows(rows, id){
  var st = loadSort(id), k = st.k, d = st.d;
  return rows.slice().sort(function(a,b){
    var x = a[k], y = b[k], r;
    if (k === 'State')      { x = (a.State === 'Running' ? 0 : 1); y = (b.State === 'Running' ? 0 : 1); }
    else if (k === 'StartMode') { var o = {Auto:0, Manual:1, Disabled:2};
                                  x = (o[a.StartMode] === undefined ? 3 : o[a.StartMode]);
                                  y = (o[b.StartMode] === undefined ? 3 : o[b.StartMode]); }
    /* the Process column shows the friendly name as the main line: sorting by
       it must follow THAT text, not the image name under it (explorer.exe).
       The other tables keep sorting on the value of their own column. */
    if (k === 'Name' && id === 'tproc') { x = a.Desc || a.Name; y = b.Desc || b.Name; }
    if (NUMKEYS[k] || typeof x === 'number') { r = (parseFloat(x)||0) - (parseFloat(y)||0); }
    else { r = String(x==null?'':x).toLowerCase().localeCompare(String(y==null?'':y).toLowerCase()); }
    if (r === 0) { var sa = (a.Display || a.Desc || a.Name || ''), sb = (b.Display || b.Desc || b.Name || '');
                   return sa.toLowerCase().localeCompare(sb.toLowerCase()); }
    return r * d;
  });
}
function paintHeaders(id){
  var st = loadSort(id), ths = document.querySelectorAll('#' + id + ' th.sortable');
  for (var i = 0; i < ths.length; i++){
    var th = ths[i], on = (th.getAttribute('data-k') === st.k);
    th.className = th.className.replace(/\s*sorted/g, '') + (on ? ' sorted' : '');
    th.querySelector('.arr').innerHTML = on ? (st.d === 1 ? '&#9650;' : '&#9660;') : '';
  }
}
function initSort(id, redraw){
  var ths = document.querySelectorAll('#' + id + ' th.sortable');
  for (var i = 0; i < ths.length; i++){
    (function(th){
      th.onclick = function(){
        var k = th.getAttribute('data-k'), st = loadSort(id);
        if (st.k === k) { st.d = -st.d; } else { st.k = k; st.d = NUMKEYS[k] ? -1 : 1; }
        saveSort(id); paintHeaders(id); redraw();
      };
    })(ths[i]);
  }
  paintHeaders(id);
}

/* ===================== tables ===================== */
function drawProcs(){
  var box = document.getElementById('procs').closest('.scroll-proc');
  var top = box ? box.scrollTop : 0;
  var f = (document.getElementById('pfilter').value || '').toLowerCase();
  var rows = sortRows(lastProcs.filter(function(p){
      if (!f) return true;
      /* the filter matches the image name, its description and the path */
      return ((p.Name || '') + ' ' + (p.Desc || '') + ' ' + (p.Path || '')).toLowerCase().indexOf(f) >= 0;
  }), 'tproc');
  document.getElementById('procs').innerHTML = rows.length ? rows.map(function(p){
     /* the friendly name of the executable ("Windows Explorer" for
        explorer.exe) is the main line, the real image name with its
        extension goes right under it, grayed; when there is no
        friendly name the image name alone is shown. The full path
        stays in the tooltip */
     var nm = '<td title="'+esc(p.Path || p.Name).replace(/"/g,'&quot;')+'">'+
              ((p.Desc) ? esc(p.Desc)+'<span class="pd">'+esc(p.Name)+'</span>'
                        : esc(p.Name))+'</td>';
     /* data-kind and data-pid are what the right-click menu reads to find the
        row it was opened on (see openCtxMenu): the DOM carries the identity,
        the data comes from lastProcs */
     return '<tr data-kind="proc" data-pid="'+p.Pid+'"'+(p.Self?' class="selfrow"':'')+'>'+nm+'<td class="num">'+p.Pid+'</td>'+
            '<td class="num '+cls(p.CpuPct)+'">'+fmt(p.CpuPct)+'</td>'+
            '<td class="num">'+fmt(p.RamMB)+'</td><td class="num">'+p.Threads+'</td><td class="num">'+p.Handles+'</td></tr>';
  }).join('') : '<tr><td colspan="6" class="sub">'+T('no_match_proc')+'</td></tr>';
  if (box) box.scrollTop = top;
}

function drawSvcs(){
  var box = document.getElementById('svclist').closest('.scroll-proc');
  var top = box ? box.scrollTop : 0;
  var f = (document.getElementById('sfilter').value || '').toLowerCase();
  var st = document.getElementById('sstate').value;
  var rows = lastSvcs.filter(function(v){
    if (f && (v.Display+' '+v.Name).toLowerCase().indexOf(f) < 0) return false;
    if (st === 'run'  && v.State !== 'Running') return false;
    if (st === 'stop' && v.State === 'Running') return false;
    if (st === 'prob' && !(v.StartMode === 'Auto' && v.State !== 'Running')) return false;
    return true;
  });
  rows = sortRows(rows, 'tsvc');
  document.getElementById('svccount').textContent = '\u2014 ' + rows.length + ' ' + T('shown_of') + ' ' + lastSvcs.length;
  document.getElementById('svclist').innerHTML = rows.length ? rows.map(function(v){
    var run = v.State === 'Running', bad = (v.StartMode === 'Auto' && !run);
    return '<tr data-kind="svc" data-name="'+esc(v.Name).replace(/"/g,'&quot;')+'"><td>'+esc(v.Display)+'</td><td class="sub">'+esc(v.Name)+'</td>'+
           '<td><span class="tag '+(run?'ok':(bad?'crit':'warn'))+'">'+esc(tState(v.State))+'</span></td>'+
           '<td>'+esc(tMode(v.StartMode))+'</td><td class="num">'+(v.Pid?v.Pid:'-')+'</td>'+
           '<td class="sub">'+esc(v.Account||'-')+'</td></tr>';
  }).join('') : '<tr><td colspan="6" class="sub">'+T('no_match_svc')+'</td></tr>';
  if (box) box.scrollTop = top;
}

function evLevelName(n){
  return n === 1 ? T('lvl_critical') : (n === 2 ? T('lvl_error')
       : (n === 3 ? T('lvl_warning') : T('lvl_info')));
}
function evLevelCls(n){ return n === 1 ? 'crit' : (n === 2 ? 'crit' : (n === 3 ? 'warn' : 'ok')); }

function drawEvents(){
  var box = document.getElementById('evlist').closest('.scroll-proc');
  var top = box ? box.scrollTop : 0;
  var f = (document.getElementById('evfilter').value || '').toLowerCase();
  var lv = document.getElementById('evlevel').value;
  var rows = lastEvents.filter(function(e){
    if (lv && String(e.Level) !== lv) return false;
    if (f && ((e.Source||'')+' '+(e.Message||'')+' '+(e.Log||'')+' '+e.EventId).toLowerCase().indexOf(f) < 0) return false;
    return true;
  });
  rows = sortRows(rows, 'tev');
  document.getElementById('evcount').textContent =
      '\u2014 ' + rows.length + ' ' + T('shown_of') + ' ' + lastEvents.length + ' \u2014 ' + T('ev_recent');
  document.getElementById('evlist').innerHTML = rows.length ? rows.map(function(e){
    var c = evLevelCls(e.Level);
    return '<tr class="'+c+'"><td>'+esc(e.Time)+'</td>'+
           '<td><span class="tag '+c+'">'+esc(evLevelName(e.Level))+'</span></td>'+
           '<td>'+esc(e.Log)+'</td><td>'+esc(e.Source)+'</td>'+
           '<td class="num">'+e.EventId+'</td>'+
           '<td title="'+esc(e.Message).replace(/"/g,'&quot;')+'">'+esc(e.Message)+'</td></tr>';
  }).join('') : '<tr><td colspan="6" class="sub">'+T('no_match_ev')+'</td></tr>';
  if (box) box.scrollTop = top;
}

/* ===================== charts ===================== */
function chart(id, series, maxFixed){
  var c = document.getElementById(id); if(!c) return;
  var w = c.clientWidth, h = c.clientHeight;
  if(c.width !== w) c.width = w; if(c.height !== h) c.height = h;
  if (!c.getContext) return;
  var x = c.getContext('2d'); if (!x) return;
  x.clearRect(0,0,w,h);
  var max = maxFixed || 1;
  if(!maxFixed){ series.forEach(function(s){ s.data.forEach(function(v){ if(v>max) max=v; }); }); max*=1.2; }
  x.strokeStyle=cssVar('--border')||'#283040'; x.lineWidth=1;
  for(var g=0; g<=4; g++){ var y=h*g/4; x.beginPath(); x.moveTo(0,y); x.lineTo(w,y); x.stroke(); }
  series.forEach(function(s){
    var d=s.data, n=d.length; if(n<2) return;
    var step = w/(n-1);
    x.beginPath();
    d.forEach(function(v,i){ var y=h-(v/max)*h*0.95; if(i===0)x.moveTo(0,y); else x.lineTo(i*step,y); });
    x.strokeStyle=s.color; x.lineWidth=2; x.stroke();
    x.lineTo(w,h); x.lineTo(0,h); x.closePath();
    x.fillStyle=s.fill; x.fill();
  });
  x.fillStyle=cssVar('--muted')||'#8b949e'; x.font='10px Segoe UI';
  x.fillText(maxFixed?'100%':(max>1024? (max/1024).toFixed(1)+' MB/s' : Math.round(max)+' KB/s'), 4, 11);
}
function draw(){
  try {
  chart('cpuchart', [{data: hist.map(function(p){return p.cpu;}), color:'#58a6ff', fill:'rgba(88,166,255,.15)'}], 100);
  chart('ramchart', [{data: hist.map(function(p){return p.ram;}), color:'#bc8cff', fill:'rgba(188,140,255,.15)'}], 100);
  chart('netchart', [
    {data: hist.map(function(p){return p.dn;}), color:'#3fb950', fill:'rgba(63,185,80,.15)'},
    {data: hist.map(function(p){return p.up;}), color:'#f0883e', fill:'rgba(240,136,62,.12)'}]);
  } catch (e) { /* charts are optional: never let them break the page */ }
}

/* ===================== disks ===================== */
function partBox(v){
  var io = (v.ReadKBs != null)
      ? '<div class="io"><span>&#9660; '+fmt(v.ReadKBs)+' KB/s</span>'+
        '<span>&#9650; '+fmt(v.WriteKBs)+' KB/s</span>'+
        '<span class="'+cls(v.BusyPct)+'">'+T('busy')+' '+fmt(v.BusyPct)+'%</span></div>' : '';
  return '<div class="part">'+
    '<div class="pt"><b>'+esc(v.Drive)+' '+esc(v.Label||'')+'</b>'+
      '<span class="tag">'+esc(v.FileSystem||v.Type)+'</span></div>'+
    '<div class="bar" style="height:10px"><i style="width:'+v.Percent+'%;background:'+col(v.Percent)+'"></i></div>'+
    '<div class="row"><span>'+T('used')+'</span><b class="'+cls(v.Percent)+'">'+fmt(v.UsedGB,2)+' GB ('+fmt(v.Percent)+'%)</b></div>'+
    '<div class="row"><span>'+T('free')+'</span><b>'+fmt(v.FreeGB,2)+' GB</b></div>'+
    '<div class="row"><span>'+T('total')+'</span><b>'+fmt(v.TotalGB,2)+' GB</b></div>'+ io +
  '</div>';
}

function diskBox(p){
  var parts = (p.Volumes && p.Volumes.length)
      ? p.Volumes.map(partBox).join('')
      : '<div class="part sub" style="text-align:center">&mdash;</div>';
  var io = (p.ReadKBs != null)
      ? '<span class="io">'+T('activity')+': &#9660; '+fmt(p.ReadKBs)+' KB/s &nbsp; &#9650; '+
        fmt(p.WriteKBs)+' KB/s &nbsp; <span class="'+cls(p.BusyPct)+'">'+T('busy')+' '+fmt(p.BusyPct)+'%</span></span>' : '';
  var badges = [p.BusType, p.MediaType, p.Interface].filter(function(x){
      return x && x !== 'Unspecified' && x !== 'Other'; });
  if (p.IsVirtual) badges.push('virtual');
  var icon = (p.Kind === 'Removable') ? '&#128189;'
           : ((p.Kind === 'Optical') ? '&#128191;' : (p.IsVirtual ? '&#9729;' : '&#128190;'));
  return '<div class="dbox'+((p.Kind && p.Kind !== 'Fixed') ? ' secondary' : '')+'"><div class="dhead">'+
    '<span class="name">'+icon+' '+esc(p.Model)+'</span>'+
    '<span class="meta">'+esc(badges.join(' \u2022 '))+' &bull; '+fmt(p.SizeGB,1)+' GB &bull; '+
      p.Partitions+' '+T('partitions')+'</span>'+
    '<span class="tag '+(p.Status=='OK'?'ok':'warn')+'">'+esc(p.Status)+'</span>'+ io +
    '</div><div class="parts">'+parts+'</div></div>';
}

function renderDisks(dk){
  var all = dk.Physical || [];
  if (!all.length && !((dk.Other||[]).length)) {
    return '<div class="sub" style="padding:14px 2px">' + T('no_data') + '</div>';
  }
  var fixed = [], extra = [];
  all.forEach(function(p){
    var k = p.Kind || 'Fixed';
    /* Only removable and optical units are listed apart: a virtual disk is a
       real disk of a virtualized server, so it belongs to the main list. */
    (k === 'Removable' || k === 'Optical' ? extra : fixed).push(p);
  });
  var out = fixed.map(diskBox).join('');
  if (extra.length){
    out += '<div class="dgroup">' + T('other_devices') + '</div>' + extra.map(diskBox).join('');
  }
  if ((dk.Other||[]).length){
    out += '<div class="dgroup">' + T('other_volumes') + '</div>' +
           '<div class="dbox secondary"><div class="parts">' + dk.Other.map(partBox).join('') + '</div></div>';
  }
  return out;
}

/* ===================== render ===================== */
var forceRepaint = false;
function render(d){
  lastData = d;
  document.getElementById('host').textContent = d.Static.ComputerName;
  document.getElementById('ts').textContent = d.Timestamp.split(' ')[1];
  document.getElementById('uptime').textContent = d.System.Uptime;

  var c = d.Cpu;
  document.getElementById('cpuname').textContent = d.Static.CpuName;
  document.getElementById('cpupct').textContent = fmt(c.TotalLoad);
  var b = document.getElementById('cpubar'); b.style.width = Math.min(100,c.TotalLoad)+'%'; b.style.background = col(c.TotalLoad);
  document.getElementById('cpughz').textContent = fmt(c.CurrentGHz,2)+' GHz / '+T('max')+' '+fmt(c.MaxGHz,2)+' GHz';
  document.getElementById('cpucores').textContent = d.Static.CpuCores+' '+T('cores')+', '+d.Static.CpuLogical+' '+
      T('threads_w')+' ('+d.Static.CpuSockets+' '+T('sockets')+')';
  /* °C or °F: the engine decides (settings.txt, else the language of Windows)
     and sends it with the reading; what arrives is always Celsius */
  var tu = (c.TempUnit === 'F') ? 'F' : 'C';
  var hasTemp = !!(c.Temperatures && c.Temperatures.length);
  document.getElementById('cputemp').innerHTML = hasTemp
      ? c.Temperatures.map(function(t){return fmt(tu === 'F' ? t.Celsius * 9 / 5 + 32 : t.Celsius)+' \u00b0'+tu;}).join(' | ') +
        (c.TempSource ? ' <small>('+esc(c.TempSource)+')</small>' : '')
      : T('temp_na');
  /* the way out of a missing temperature is offered exactly while it is
     missing: with a real reading there is nothing to explain */
  document.getElementById('temphelp').className = hasTemp ? 'helpbtn' : 'helpbtn on';
  document.getElementById('cpunow').innerHTML = '<span class="'+cls(c.TotalLoad)+'">'+fmt(c.TotalLoad)+'%</span>';
  document.getElementById('corelist').innerHTML = (c.PerCore||[]).map(function(x){
     return '<div class="core"><div>'+T('core')+' '+esc(x.Core)+'</div><b class="'+cls(x.Load)+'">'+fmt(x.Load)+'%</b>'+
            '<div class="bar" style="margin:4px 0 0"><i style="width:'+Math.min(100,x.Load)+'%;background:'+col(x.Load)+'"></i></div></div>';
  }).join('');

  var m = d.Memory;
  document.getElementById('rampct').textContent = fmt(m.Percent);
  var rb = document.getElementById('rambar'); rb.style.width = m.Percent+'%'; rb.style.background = col(m.Percent);
  document.getElementById('ramnow').innerHTML = '<span class="'+cls(m.Percent)+'">'+fmt(m.Percent)+'%</span>';
  document.getElementById('ramused').textContent = fmt(m.UsedGB,2)+' GB';
  document.getElementById('ramfree').textContent = fmt(m.FreeGB,2)+' GB';
  document.getElementById('ramtot').textContent  = fmt(m.TotalGB,2)+' GB';
  document.getElementById('ramswap').textContent = fmt(m.SwapTotGB - m.SwapFreeGB,2)+' / '+fmt(m.SwapTotGB,2)+' GB';
  document.getElementById('rammod').innerHTML = (m.Modules||[]).map(function(x){
      return '<span class="tag">'+esc(x.Slot)+': '+x.SizeGB+' GB @ '+x.SpeedMhz+' MHz</span>'; }).join(' ');

  var n = d.Network;
  document.getElementById('netdn').innerHTML = (n.TotalDownKBs>1024? fmt(n.TotalDownKBs/1024,2)+' <small>MB/s</small>' : fmt(n.TotalDownKBs)+' <small>KB/s</small>');
  document.getElementById('netup').innerHTML = (n.TotalUpKBs>1024? fmt(n.TotalUpKBs/1024,2)+' <small>MB/s</small>' : fmt(n.TotalUpKBs)+' <small>KB/s</small>');
  document.getElementById('tcp').textContent = n.Connections;
  document.getElementById('nics').innerHTML = (n.Adapters||[]).map(function(a){
     return '<tr><td>'+esc(a.Name)+'<div class="sub">'+esc(a.Description)+' &bull; '+esc(a.LinkSpeed)+'</div></td>'+
            '<td><span class="tag '+(a.Status=='Up'?'ok':'crit')+'">'+esc(a.Status)+'</span></td>'+
            '<td class="num">'+fmt(a.DownKBs)+'</td><td class="num">'+fmt(a.UpKBs)+'</td>'+
            '<td class="num">'+fmt(a.TotalRxGB,2)+' GB</td><td class="num">'+fmt(a.TotalTxGB,2)+' GB</td></tr>';
  }).join('');
  document.getElementById('ipinfo').innerHTML = (n.IpConfig||[]).map(function(i){
     return '<div style="margin-bottom:10px;padding-bottom:8px;border-bottom:1px solid #283040">'+
       '<b>'+esc(i.Description)+'</b><div class="kv" style="margin-top:4px">'+
       '<b>'+T('ipv4')+'</b><span>'+esc(i.IPv4)+'</span>'+
       '<b>'+T('subnet')+'</b><span>'+esc(i.Subnet)+'</span>'+
       '<b>'+T('gateway')+'</b><span>'+esc(i.Gateway||'-')+'</span>'+
       '<b>'+T('dns')+'</b><span>'+esc(i.Dns||'-')+'</span>'+
       '<b>'+T('mac')+'</b><span>'+esc(i.Mac)+'</span>'+
       '<b>'+T('dhcp')+'</b><span>'+(i.Dhcp?T('yes')+' ('+esc(i.DhcpServer||'')+')':T('no_static'))+'</span>'+
       '<b>'+T('ipv6')+'</b><span>'+esc(i.IPv6||'-')+'</span></div></div>';
  }).join('');

  document.getElementById('disks').innerHTML = renderDisks(d.Disks);

  var s = d.Static, sy = d.System;
  document.getElementById('osinfo').innerHTML =
    [[T('os'),s.OSName],[T('version_build'),s.OSVersion+' ('+T('build')+' '+s.OSBuild+')'],
     [T('architecture'),s.OSArch],[T('computer_name'),s.ComputerName],[T('domain'),s.Domain],
     [T('manufacturer'),s.Manufacturer+' '+s.Model],[T('bios'),s.Bios],[T('serial'),s.SerialNumber],
     [T('installed_on'),s.OSInstall],[T('last_boot'),sy.LastBoot],[T('uptime'),sy.Uptime],
     [T('processes'),sy.ProcessCount],[T('sessions'),sy.LoggedUsers]]
    .map(function(r){ return '<b>'+esc(r[0])+'</b><span>'+esc(r[1])+'</span>'; }).join('');

  lastProcs = d.Processes || [];
  document.getElementById('procount').textContent = '\u2014 ' + lastProcs.length + ' ' + T('procs_running');
  drawProcs();

  lastSvcs = d.Services || [];
  var down = (sy.ServicesDown||[]).length;
  document.getElementById('svcsummary').innerHTML =
      T('st_running')+': <b class="ok">'+sy.ServicesRun+'</b> &nbsp;&bull;&nbsp; '+
      T('st_stopped')+': <b>'+(sy.ServicesTotal-sy.ServicesRun)+'</b> &nbsp;&bull;&nbsp; '+
      T('auto_not_started')+': <b class="'+(down?'crit':'ok')+'">'+down+'</b> &nbsp;&bull;&nbsp; '+
      T('sm_manual')+': <b>'+sy.ServicesManual+'</b> &nbsp;&bull;&nbsp; '+
      T('sm_disabled')+': <b>'+sy.ServicesDisab+'</b> &nbsp;&bull;&nbsp; '+
      T('total')+': <b>'+sy.ServicesTotal+'</b>';
  drawSvcs();

  lastEvents = d.Events || [];
  var se = quickSig(lastEvents);
  if (se !== sig.ev || forceRepaint) { sig.ev = se; drawEvents(); }
}

/* ===================== polling ===================== */
/* The connection state is kept as a key, not as text: this way a language
   change repaints it immediately instead of waiting for the next poll (which
   with a 5 minute interval would mean staring at the old language for ages). */
var CONN = 'offline';
var CONNEXTRA = '';
function setConn(key, extra){
  CONN = key; CONNEXTRA = extra || '';
  paintConn();
}
function paintConn(){
  var el = document.getElementById('conn');
  if (el) el.textContent = T(CONN) + CONNEXTRA;
}

function load(){
  fetch('api/stats?_=' + Date.now()).then(function(r){ return r.json(); }).then(function(j){
    setConn('online');
    document.getElementById('err').textContent = '';
    hist = j.History || [];
    render(j.Current); draw();
  }).catch(function(e){
    setConn('offline');
    document.getElementById('err').textContent = T('error_l') + ': ' + e;
  });
}

var timer = setInterval(load, 5000);

document.getElementById('pfilter').addEventListener('input', drawProcs);
document.getElementById('sfilter').addEventListener('input', drawSvcs);
document.getElementById('sstate').addEventListener('change', drawSvcs);
document.getElementById('evfilter').addEventListener('input', drawEvents);
document.getElementById('evlevel').addEventListener('change', drawEvents);
document.getElementById('rate').onchange = function(){
  LOCAL.refresh = (this.value === '') ? null : parseFloat(this.value);
  saveLocal(); applyRate();
};
document.getElementById('setbtn').onclick = openSettings;
document.getElementById('setclose').onclick = closeSettings;
document.getElementById('setcancel').onclick = closeSettings;
document.getElementById('setsave').onclick = function(){ applySettings(); };
document.getElementById('setreset').onclick = resetSettings;
document.getElementById('pwok').onclick = submitPwPopup;
document.getElementById('pwcancel').onclick = closePwPopup;
document.getElementById('pwclose').onclick = closePwPopup;
document.getElementById('pwmodal').onclick = function(e){ if (e.target === this) closePwPopup(); };
document.getElementById('pwinput').addEventListener('keydown', function(e){
  if (e.key === 'Enter') { e.preventDefault(); submitPwPopup(); }
  if (e.key === 'Escape') { e.preventDefault(); closePwPopup(); }
});
/* While the password has not been given yet, every interaction with the
   server options is stopped and the popup opens instead. After that the
   options behave normally (and Save sends the password with the changes). */
['pointerdown', 'click', 'keydown'].forEach(function(ev){
  document.getElementById('srvrow').addEventListener(ev, function(e){
    if (pwLocked()) {
      e.preventDefault();
      e.stopPropagation();
      openPwPopup(pwRealTarget(e.target));
    }
  }, true);
});
document.getElementById('setmodal').onclick = function(e){ if (e.target === this) closeSettings(); };
document.getElementById('pwmodal').onclick = function(e){ if (e.target === this) closePwPopup(); };
document.getElementById('themebtn').onclick = function(){ applyTheme(THEME === 'dark' ? 'light' : 'dark', true); };
document.getElementById('langbtn').onclick = function(){ document.getElementById('langmodal').className = 'modal on'; };
document.getElementById('langclose').onclick = function(){ document.getElementById('langmodal').className = 'modal'; };
document.getElementById('langmodal').onclick = function(e){ if (e.target === this) closeLang(); };
document.getElementById('aboutbtn').onclick = openAbout;
document.getElementById('aboutclose').onclick = closeAbout;
document.getElementById('aboutok').onclick = closeAbout;
document.getElementById('aboutreload').onclick = openAbout;  document.getElementById('aboutmodal').onclick = function(e){ if (e.target === this) closeAbout(); };
document.getElementById('temphelp').onclick = openTempHelp;
document.getElementById('tempclose').onclick = closeTempHelp;
document.getElementById('tempok').onclick = closeTempHelp;
document.getElementById('tempmodal').onclick = function(e){ if (e.target === this) closeTempHelp(); };
document.getElementById('propmodal').onclick = function(e){ if (e.target === this) closeProps(); };
document.getElementById('propclose').onclick = closeProps;
document.getElementById('propok').onclick = closeProps;
/* the right button: only on a row of the process and service tables, so the
   menu of the browser stays exactly what it was everywhere else */
document.addEventListener('contextmenu', function(e){
  var tr = (e.target && e.target.closest) ? e.target.closest('tr[data-kind]') : null;
  if (!tr) { return; }
  var kind = tr.getAttribute('data-kind'), o = null, i;
  if (kind === 'proc'){
    var pid = parseInt(tr.getAttribute('data-pid'), 10);
    for (i = 0; i < lastProcs.length; i++) { if (lastProcs[i].Pid === pid) { o = lastProcs[i]; break; } }
  } else {
    var nm = tr.getAttribute('data-name');
    for (i = 0; i < lastSvcs.length; i++) { if (lastSvcs[i].Name === nm) { o = lastSvcs[i]; break; } }
  }
  if (!o) { return; }
  e.preventDefault();
  openCtxMenu(e.clientX, e.clientY, kind, o);
});
document.addEventListener('pointerdown', function(e){
  var m = document.getElementById('ctxmenu');
  if (m && m.className === 'ctxmenu on' && !m.contains(e.target)) { closeCtxMenu(); }
});
/* a menu left hanging next to a row that moved, or that is no longer on
   screen, would say the wrong thing about it */
document.addEventListener('scroll', closeCtxMenu, true);
document.addEventListener('keydown', function(e){
  if (e.key !== 'Escape') { return; }
  if (document.getElementById('aboutmodal').className === 'modal on'){
    e.preventDefault(); closeAbout();
  }
  if (document.getElementById('tempmodal').className === 'modal on'){
    e.preventDefault(); closeTempHelp();
  }
  if (document.getElementById('propmodal').className === 'modal on'){
    e.preventDefault(); closeProps();
  }
  closeCtxMenu();
});
/* a resize redraws the charts and takes the menu away: the row it belonged to
   is not where it was any more */
window.addEventListener('resize', function(){ closeCtxMenu(); draw(); });
initSort('tproc', drawProcs);
initSort('tsvc', drawSvcs);
initSort('tev', drawEvents);
document.getElementById('syslang').textContent = SYSLANG;
loadLocal();
initTheme();

/* boot sequence: language list -> chosen language -> data */
loadServer().then(function(){
  try { applySections(); applyRate(); } catch (e) { }
  return fetchLangList();
}).catch(function(){ return []; }).then(function(list){
  LANGS = (list && list.length) ? list : [{code:'en-US', native:'English', english:'English', dir:'ltr'}];
  return setLang(pickLang(), false);
}).catch(function(){ }).then(function(){
  try { fillRates(); } catch (e) { }
  load();
});
