from flask import (
    Flask, request, redirect, url_for, flash, get_flashed_messages,
    send_file, Response, session,
)
import subprocess, tempfile, os, shutil, secrets, threading, html, hmac, time
from collections import defaultdict, deque
from datetime import timedelta

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024
# Session cookies signed with this key. Kept STABLE across restarts so
# existing family sessions survive `rebuild home-server` — otherwise every
# rebuild would force everyone to log in again.
def _load_secret_key() -> bytes:
    creds_dir = os.environ.get('CREDENTIALS_DIRECTORY')
    if creds_dir:
        path = os.path.join(creds_dir, 'password')
        if os.path.exists(path):
            with open(path, 'rb') as f:
                # Derive the session key deterministically from the password.
                # Rotating the password also invalidates all sessions — desirable.
                import hashlib
                return hashlib.sha256(f.read().strip()).digest()
    return secrets.token_bytes(32)

app.secret_key = _load_secret_key()
app.permanent_session_lifetime = timedelta(days=30)

# ────────────────────────────────────────────────────────────────
# Auth: cookie-based, password-only
# ────────────────────────────────────────────────────────────────
# Simple password-only login. First visit shows a form with just a password
# field (no username to type). On success, sets a signed session cookie
# valid for 30 days; subsequent visits pass through silently.
#
# Rate limit: 20 failed attempts per IP per hour. Way more forgiving than
# the previous 5/15min so a family member fat-fingering the password 5
# times doesn't lock everyone at the house out. Still uncrackable — an
# 11-char lowercase password (~52 bits) at 20/hour ≥ 10^12 years brute force.
#
# Client IP source: Cloudflare tunnel passes the real client IP in the
# CF-Connecting-IP header. Falling back to request.remote_addr would
# bucket every visitor as "the CF edge IP that hit us" — useless for
# rate limiting.
def _load_password() -> str:
    creds_dir = os.environ.get('CREDENTIALS_DIRECTORY')
    if creds_dir:
        path = os.path.join(creds_dir, 'password')
        if os.path.exists(path):
            with open(path) as f:
                return f.read().strip()
    return os.environ.get('PRINT_SERVER_PASSWORD', '').strip()

PRINT_PASSWORD = _load_password()
RATE_WINDOW_SECONDS = 3600
RATE_MAX_FAILURES  = 20

_rate_lock = threading.Lock()
_failed_attempts: 'defaultdict[str, deque]' = defaultdict(deque)

def _client_ip() -> str:
    return request.headers.get('CF-Connecting-IP') or request.remote_addr or 'unknown'

def _check_rate_ok(ip: str) -> bool:
    now = time.time()
    with _rate_lock:
        attempts = _failed_attempts[ip]
        while attempts and now - attempts[0] > RATE_WINDOW_SECONDS:
            attempts.popleft()
        return len(attempts) < RATE_MAX_FAILURES

def _record_failure(ip: str) -> None:
    with _rate_lock:
        _failed_attempts[ip].append(time.time())

def _clear_failures(ip: str) -> None:
    with _rate_lock:
        _failed_attempts.pop(ip, None)

def _login_page(error: str = '') -> Response:
    err_html = f'<div class="err">{html.escape(error)}</div>' if error else ''
    body = f'''<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Printer</title>
<style>
  body {{ background:#1a1a1a; color:#e5e5e5; font-family:system-ui,sans-serif;
         display:flex; align-items:center; justify-content:center; min-height:100vh; margin:0; }}
  form {{ background:#232323; padding:2rem; border-radius:8px; width:min(90%, 320px); }}
  h1 {{ margin:0 0 1rem; font-size:1.25rem; text-align:center; }}
  input {{ width:100%; padding:.75rem; margin:.5rem 0; box-sizing:border-box;
           background:#1a1a1a; color:#e5e5e5; border:1px solid #333; border-radius:4px; font-size:1rem; }}
  button {{ width:100%; padding:.75rem; margin-top:.5rem;
            background:#1e3a5f; color:#fff; border:0; border-radius:4px; font-size:1rem; cursor:pointer; }}
  button:hover {{ background:#274b78; }}
  .err {{ background:#5a1e1e; color:#ffb3b3; padding:.5rem; border-radius:4px;
          margin-bottom:.75rem; text-align:center; font-size:.9rem; }}
</style></head><body>
<form method="post" action="/login">
  <h1>Printer</h1>
  {err_html}
  <input type="password" name="password" placeholder="Password" autofocus required>
  <button type="submit">Unlock</button>
</form>
</body></html>'''
    return Response(body, status=200, mimetype='text/html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if not PRINT_PASSWORD:
        return Response('Server misconfigured: PRINT_SERVER_PASSWORD unset', status=503)

    ip = _client_ip()
    if not _check_rate_ok(ip):
        return Response(
            'Too many failed attempts. Try again in an hour.',
            status=429,
            headers={'Retry-After': str(RATE_WINDOW_SECONDS)},
        )

    if request.method == 'POST':
        pw = request.form.get('password', '')
        if hmac.compare_digest(pw, PRINT_PASSWORD):
            _clear_failures(ip)
            session.permanent = True
            session['auth'] = True
            return redirect(request.args.get('next') or url_for('index'))
        _record_failure(ip)
        return _login_page(error='Wrong password.')

    return _login_page()

@app.before_request
def _require_auth():
    # Fail closed on misconfiguration.
    if not PRINT_PASSWORD:
        return Response('Server misconfigured: PRINT_SERVER_PASSWORD unset', status=503)

    # /login is the only route that bypasses the auth check.
    if request.endpoint == 'login':
        return None

    if session.get('auth'):
        return None

    # Preserve where the user was heading so they land there after login.
    return redirect(url_for('login', next=request.path))

# Doc formats need LibreOffice to convert to PDF before CUPS can print them.
DOC_EXTS = {'.docx', '.odt', '.doc', '.rtf'}
IMG_EXTS = {'.jpg', '.jpeg', '.png', '.gif', '.tiff', '.bmp'}
ALLOWED = {'.pdf', '.txt'} | IMG_EXTS | DOC_EXTS
PAGE_SIZES = ['A4', 'Letter', 'Legal', 'A5', 'Executive']
SCAN_DPIS = [150, 300, 600]
SCAN_MODES = ['Color', 'Gray']

STRINGS = {
    'en': {
        'title': 'Print',
        'heading': 'Print a document',
        'file': 'File',
        'copies': 'Copies',
        'paper': 'Paper size',
        'send': 'Send to printer',
        'no_file': 'No file selected.',
        'bad_ext': 'Unsupported format: {ext}. Use PDF or an image.',
        'sent_one': 'Sent 1 copy to the printer.',
        'sent_many': 'Sent {n} copies to the printer.',
        'error': 'Print error: {err}',
        'switch_to': 'FR',
        'theme_to_light': 'LIGHT',
        'theme_to_dark': 'DARK',
        'nav_print': 'Print',
        'nav_scan': 'Scan',
        'scan_title': 'Scan',
        'scan_heading': 'Scan a document',
        'scan_start_heading': 'Start a scan',
        'mode': 'Color mode',
        'mode_color': 'Color',
        'mode_gray': 'Grayscale',
        'resolution': 'Resolution',
        'dpi_150': '150 dpi (draft)',
        'dpi_300': '300 dpi (normal)',
        'dpi_600': '600 dpi (high quality)',
        'start_scan': 'Place first page, then scan',
        'session_heading': 'Scan in progress',
        'pages_scanned_one': '1 page scanned',
        'pages_scanned_many': '{n} pages scanned',
        'add_page': 'Scan next page',
        'finish_pdf': 'Finish — download PDF',
        'finish_print': 'Finish — send to printer',
        'cancel_scan': 'Cancel',
        'scan_error': 'Scan error: {err}',
        'scan_no_device': 'No scanner found. Check the USB cable and power.',
        'scan_busy': 'A scan is already in progress.',
        'scan_page_added_one': 'Scanned page 1.',
        'scan_page_added_many': 'Scanned page {n}.',
        'scan_pdf_ready': 'PDF ready ({n} pages).',
        'scan_printed_one': 'Sent scan (1 page) to the printer.',
        'scan_printed_many': 'Sent scan ({n} pages) to the printer.',
        'scan_cancelled': 'Scan cancelled.',
    },
    'fr': {
        'title': 'Imprimer',
        'heading': 'Imprimer un document',
        'file': 'Fichier',
        'copies': 'Copies',
        'paper': 'Format papier',
        'send': 'Envoyer à l\'imprimante',
        'no_file': 'Aucun fichier sélectionné.',
        'bad_ext': 'Format non pris en charge : {ext}. Utilisez un PDF ou une image.',
        'sent_one': '1 copie envoyée à l\'imprimante.',
        'sent_many': '{n} copies envoyées à l\'imprimante.',
        'error': 'Erreur d\'impression : {err}',
        'switch_to': 'EN',
        'theme_to_light': 'CLAIR',
        'theme_to_dark': 'SOMBRE',
        'nav_print': 'Imprimer',
        'nav_scan': 'Numériser',
        'scan_title': 'Numériser',
        'scan_heading': 'Numériser un document',
        'scan_start_heading': 'Nouvelle numérisation',
        'mode': 'Mode couleur',
        'mode_color': 'Couleur',
        'mode_gray': 'Niveaux de gris',
        'resolution': 'Résolution',
        'dpi_150': '150 ppp (brouillon)',
        'dpi_300': '300 ppp (normal)',
        'dpi_600': '600 ppp (haute qualité)',
        'start_scan': 'Placez la première page puis numérisez',
        'session_heading': 'Numérisation en cours',
        'pages_scanned_one': '1 page numérisée',
        'pages_scanned_many': '{n} pages numérisées',
        'add_page': 'Numériser la page suivante',
        'finish_pdf': 'Terminer — télécharger le PDF',
        'finish_print': 'Terminer — envoyer à l\'imprimante',
        'cancel_scan': 'Annuler',
        'scan_error': 'Erreur de numérisation : {err}',
        'scan_no_device': 'Aucun scanner trouvé. Vérifiez le câble USB et l\'alimentation.',
        'scan_busy': 'Une numérisation est déjà en cours.',
        'scan_page_added_one': 'Page 1 numérisée.',
        'scan_page_added_many': 'Page {n} numérisée.',
        'scan_pdf_ready': 'PDF prêt ({n} pages).',
        'scan_printed_one': 'Numérisation (1 page) envoyée à l\'imprimante.',
        'scan_printed_many': 'Numérisation ({n} pages) envoyée à l\'imprimante.',
        'scan_cancelled': 'Numérisation annulée.',
    },
}

# --- CSS + shared layout ----------------------------------------------------

CSS = """
  :root {
    --fs: clamp(1rem, 0.9rem + 0.6vw, 1.25rem);
    --bg: #1a1a1a;
    --fg: #e5e5e5;
    --muted: #999;
    --border: #333;
    --input-bg: #232323;
    --btn-bg: #2a2a2a;
    --btn-bg-hover: #3a3a3a;
    --btn-primary-bg: #1e3a5f;
    --btn-primary-hover: #274b78;
    --ok-bg: #14532d;
    --ok-fg: #86efac;
    --err-bg: #7f1d1d;
    --err-fg: #fca5a5;
    --nav-active: #3a3a3a;
  }
  :root.light {
    --bg: #fafafa;
    --fg: #1a1a1a;
    --muted: #666;
    --border: #d0d0d0;
    --input-bg: #ffffff;
    --btn-bg: #e5e7eb;
    --btn-bg-hover: #d1d5db;
    --btn-primary-bg: #2563eb;
    --btn-primary-hover: #1d4ed8;
    --ok-bg: #dcfce7;
    --ok-fg: #15803d;
    --err-bg: #fee2e2;
    --err-fg: #b91c1c;
    --nav-active: #d1d5db;
  }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body {
    font-family: system-ui, -apple-system, sans-serif;
    font-size: var(--fs);
    background: var(--bg);
    color: var(--fg);
    line-height: 1.5;
    min-height: 100vh;
    display: flex;
    justify-content: center;
    padding: clamp(1rem, 4vw, 2.5rem);
  }
  main { width: 100%; max-width: 32rem; }
  header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
    gap: .5rem;
    flex-wrap: wrap;
  }
  nav { display: flex; gap: .35rem; }
  nav a {
    font-size: .95em;
    font-weight: 600;
    text-decoration: none;
    color: var(--fg);
    padding: .4rem .8rem;
    border: 1px solid var(--border);
    border-radius: .4rem;
    background: var(--input-bg);
  }
  nav a.active { background: var(--nav-active); }
  nav a:hover { background: var(--btn-bg); }
  .toggles { display: flex; gap: .35rem; }
  .toggle {
    font-size: .85em;
    font-weight: 600;
    text-decoration: none;
    color: var(--muted);
    padding: .4rem .7rem;
    border: 1px solid var(--border);
    border-radius: .4rem;
    background: var(--input-bg);
  }
  .toggle:hover { background: var(--btn-bg); }
  h1 {
    font-size: clamp(1.4rem, 1.1rem + 1.5vw, 1.9rem);
    margin: 0 0 1.5rem;
  }
  form { display: flex; flex-direction: column; gap: 1.25rem; }
  form + form { margin-top: 1rem; }
  label {
    display: flex;
    flex-direction: column;
    gap: .35rem;
    font-weight: 500;
  }
  input[type=file], input[type=number], select {
    font: inherit;
    padding: .6rem .75rem;
    border: 1px solid var(--border);
    border-radius: .5rem;
    background: var(--input-bg);
    color: var(--fg);
    width: 100%;
  }
  input[type=file] { padding: .5rem; }
  button {
    font: inherit;
    font-weight: 600;
    padding: .8rem 1.5rem;
    border: 1px solid var(--border);
    border-radius: .5rem;
    background: var(--btn-bg);
    color: var(--fg);
    cursor: pointer;
    min-height: 48px;
    width: 100%;
  }
  button:hover { background: var(--btn-bg-hover); }
  button:active { transform: scale(.98); }
  button.primary {
    background: var(--btn-primary-bg);
    border-color: var(--btn-primary-bg);
    color: #fff;
  }
  button.primary:hover { background: var(--btn-primary-hover); }
  .msg {
    padding: .75rem 1rem;
    border-radius: .5rem;
    margin-top: 1rem;
  }
  .ok { background: var(--ok-bg); color: var(--ok-fg); }
  .err { background: var(--err-bg); color: var(--err-fg); }
  .count {
    padding: 1rem;
    text-align: center;
    background: var(--input-bg);
    border: 1px solid var(--border);
    border-radius: .5rem;
    font-size: 1.15em;
  }
  .action-row { display: flex; flex-direction: column; gap: .5rem; }
"""


def pick_lang():
    lang = request.args.get('lang', 'en')
    return lang if lang in STRINGS else 'en'


def pick_theme():
    theme = request.args.get('theme', 'dark')
    return theme if theme in ('dark', 'light') else 'dark'


def qs(**overrides):
    """Query string preserving lang/theme + overrides."""
    params = {'lang': pick_lang(), 'theme': pick_theme(), **overrides}
    return '?' + '&'.join(f'{k}={v}' for k, v in params.items())


def flash_msg(kind, key, **kwargs):
    """Localize now, flash for the next request."""
    s = STRINGS[pick_lang()]
    text = s[key].format(**kwargs) if kwargs else s[key]
    flash(text, kind)


def render_messages():
    parts = []
    for kind, text in get_flashed_messages(with_categories=True):
        parts.append(f'<p class="msg {kind}">{html.escape(text)}</p>')
    return '\n'.join(parts)


def layout(active, heading, body_html, title):
    lang = pick_lang()
    theme = pick_theme()
    s = STRINGS[lang]
    other_lang = 'fr' if lang == 'en' else 'en'
    other_theme = 'light' if theme == 'dark' else 'dark'
    theme_label = s['theme_to_light'] if theme == 'dark' else s['theme_to_dark']
    theme_class = 'light' if theme == 'light' else ''
    print_active = ' class=active' if active == 'print' else ''
    scan_active = ' class=active' if active == 'scan' else ''
    return f'''<!DOCTYPE html>
<html lang="{lang}" class="{theme_class}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>{CSS}</style>
</head>
<body>
<main>
  <header>
    <nav>
      <a{print_active} href="/{qs()}">{s['nav_print']}</a>
      <a{scan_active} href="/scan{qs()}">{s['nav_scan']}</a>
    </nav>
    <div class=toggles>
      <a class=toggle href="{qs(lang=other_lang)}">{s['switch_to']}</a>
      <a class=toggle href="{qs(theme=other_theme)}">{theme_label}</a>
    </div>
  </header>
  <h1>{heading}</h1>
  {body_html}
  {render_messages()}
</main>
</body>
</html>'''


# --- Print ------------------------------------------------------------------

def print_form():
    s = STRINGS[pick_lang()]
    size_options = ''.join(
        f'<option value="{sz}"{" selected" if sz == "A4" else ""}>{sz}</option>'
        for sz in PAGE_SIZES
    )
    return f'''<form method=post enctype=multipart/form-data action="/print{qs()}">
    <label>
      {s['file']}
      <input type=file name=file required accept=".pdf,.txt,.docx,.odt,.doc,.rtf,.jpg,.jpeg,.png,.gif,.tiff,.bmp">
    </label>
    <label>
      {s['copies']}
      <input type=number name=copies value=1 min=1 max=50>
    </label>
    <label>
      {s['paper']}
      <select name=media>
        {size_options}
      </select>
    </label>
    <button type=submit class=primary>{s['send']}</button>
  </form>'''


@app.get('/')
def index():
    s = STRINGS[pick_lang()]
    return layout('print', s['heading'], print_form(), s['title'])


def do_print(path, copies, media):
    """Return (ok, err_text)."""
    cmd = ['lp', '-n', str(copies), '-o', f'media={media}', path]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode == 0:
        return True, ''
    return False, (r.stderr or r.stdout).strip() or 'lp failed'


@app.post('/print')
def print_file():
    f = request.files.get('file')
    if not f or not f.filename:
        flash_msg('err', 'no_file')
        return redirect(url_for('index', **_lt()))

    ext = os.path.splitext(f.filename)[1].lower()
    if ext not in ALLOWED:
        flash_msg('err', 'bad_ext', ext=ext)
        return redirect(url_for('index', **_lt()))

    try:
        copies = max(1, min(50, int(request.form.get('copies', '1'))))
    except ValueError:
        copies = 1

    media = request.form.get('media', 'A4')
    if media not in PAGE_SIZES:
        media = 'A4'

    tmpdir = tempfile.mkdtemp()
    try:
        upload = os.path.join(tmpdir, 'upload' + ext)
        f.save(upload)

        if ext in DOC_EXTS:
            # LibreOffice needs a writable user profile; scope it to tmpdir
            # so we don't need HOME set for the print-server system user.
            r = subprocess.run(
                ['soffice',
                 f'-env:UserInstallation=file://{tmpdir}/lo-profile',
                 '--headless', '--convert-to', 'pdf',
                 '--outdir', tmpdir, upload],
                capture_output=True, text=True, timeout=120,
                env={**os.environ, 'HOME': tmpdir, 'XDG_RUNTIME_DIR': tmpdir},
            )
            print_path = os.path.join(tmpdir, 'upload.pdf')
            if r.returncode != 0 or not os.path.exists(print_path):
                err = (r.stderr or r.stdout).strip() or 'conversion failed'
                flash_msg('err', 'error', err=err)
                return redirect(url_for('index', **_lt()))
        else:
            print_path = upload

        ok, err = do_print(print_path, copies, media)
        if ok:
            key = 'sent_one' if copies == 1 else 'sent_many'
            flash_msg('ok', key, n=copies)
        else:
            flash_msg('err', 'error', err=err)
        return redirect(url_for('index', **_lt()))
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def _lt():
    """lang+theme dict for url_for redirects."""
    return {'lang': pick_lang(), 'theme': pick_theme()}


# --- Scan -------------------------------------------------------------------

_scan_lock = threading.Lock()
_scan = None  # dict: {tmpdir, pages: [path...], dpi, mode}


def scan_start_form():
    s = STRINGS[pick_lang()]
    mode_options = ''.join(
        f'<option value="{m}"{" selected" if m == "Gray" else ""}>'
        f'{s["mode_" + m.lower()]}</option>'
        for m in SCAN_MODES
    )
    dpi_options = ''.join(
        f'<option value="{d}"{" selected" if d == 300 else ""}>'
        f'{s["dpi_" + str(d)]}</option>'
        for d in SCAN_DPIS
    )
    return f'''<form method=post action="/scan/start{qs()}">
    <label>
      {s['mode']}
      <select name=mode>{mode_options}</select>
    </label>
    <label>
      {s['resolution']}
      <select name=dpi>{dpi_options}</select>
    </label>
    <button type=submit class=primary>{s['start_scan']}</button>
  </form>'''


def scan_session_body():
    global _scan
    s = STRINGS[pick_lang()]
    n = len(_scan['pages'])
    count_key = 'pages_scanned_one' if n == 1 else 'pages_scanned_many'
    count_text = s[count_key].format(n=n) if n != 1 else s[count_key]
    return f'''<div class=count>{count_text}</div>
  <div class=action-row>
    <form method=post action="/scan/page{qs()}">
      <button type=submit class=primary>{s['add_page']}</button>
    </form>
    <form method=post action="/scan/finish{qs()}">
      <input type=hidden name=dest value=pdf>
      <button type=submit>{s['finish_pdf']}</button>
    </form>
    <form method=post action="/scan/finish{qs()}">
      <input type=hidden name=dest value=print>
      <button type=submit>{s['finish_print']}</button>
    </form>
    <form method=post action="/scan/cancel{qs()}">
      <button type=submit>{s['cancel_scan']}</button>
    </form>
  </div>'''


@app.get('/scan')
def scan_index():
    s = STRINGS[pick_lang()]
    with _scan_lock:
        if _scan and _scan['pages']:
            return layout('scan', s['session_heading'], scan_session_body(),
                          s['scan_title'])
    return layout('scan', s['scan_start_heading'], scan_start_form(),
                  s['scan_title'])


def _scanimage_page(mode, dpi, out_path):
    """Run scanimage. Returns (ok, err_text)."""
    r = subprocess.run(
        ['scanimage', '--format=png', f'--resolution={dpi}',
         f'--mode={mode}', '-o', out_path],
        capture_output=True, text=True, timeout=180,
    )
    if r.returncode == 0 and os.path.exists(out_path) and os.path.getsize(out_path) > 0:
        return True, ''
    err = (r.stderr or r.stdout).strip() or 'scanimage failed'
    return False, err


@app.post('/scan/start')
def scan_start():
    global _scan
    mode = request.form.get('mode', 'Gray')
    if mode not in SCAN_MODES:
        mode = 'Gray'
    try:
        dpi = int(request.form.get('dpi', '300'))
    except ValueError:
        dpi = 300
    if dpi not in SCAN_DPIS:
        dpi = 300

    with _scan_lock:
        if _scan is not None:
            flash_msg('err', 'scan_busy')
            return redirect(url_for('scan_index', **_lt()))
        tmpdir = tempfile.mkdtemp(prefix='scan-')
        _scan = {'tmpdir': tmpdir, 'pages': [], 'dpi': dpi, 'mode': mode}

    _add_scan_page()
    return redirect(url_for('scan_index', **_lt()))


def _add_scan_page():
    """Scan one page into current session. Flashes result. Assumes _scan set."""
    global _scan
    # Snapshot under lock, run scanimage outside lock (slow), commit under lock.
    with _scan_lock:
        if _scan is None:
            flash_msg('err', 'scan_error', err='no active session')
            return
        mode = _scan['mode']
        dpi = _scan['dpi']
        tmpdir = _scan['tmpdir']
        page_num = len(_scan['pages']) + 1

    out = os.path.join(tmpdir, f'page-{page_num:03d}.png')
    ok, err = _scanimage_page(mode, dpi, out)

    with _scan_lock:
        if _scan is None or _scan['tmpdir'] != tmpdir:
            # Session was cancelled while scanning; drop the file.
            if os.path.exists(out):
                os.unlink(out)
            return
        if ok:
            _scan['pages'].append(out)
            key = 'scan_page_added_one' if page_num == 1 else 'scan_page_added_many'
            flash_msg('ok', key, n=page_num)
        else:
            # If the very first page failed, tear down the session so the user
            # sees the start form again instead of a "0 pages, add another" UI.
            if not _scan['pages']:
                shutil.rmtree(_scan['tmpdir'], ignore_errors=True)
                _scan = None
            low = err.lower()
            if 'no such device' in low or 'no scanners' in low or 'no devices' in low:
                flash_msg('err', 'scan_no_device')
            else:
                flash_msg('err', 'scan_error', err=err[:200])


@app.post('/scan/page')
def scan_page():
    _add_scan_page()
    return redirect(url_for('scan_index', **_lt()))


def _combine_pdf(pages, out_path):
    """img2pdf pages into a single PDF."""
    r = subprocess.run(
        ['img2pdf', *pages, '-o', out_path],
        capture_output=True, text=True, timeout=120,
    )
    if r.returncode == 0 and os.path.exists(out_path):
        return True, ''
    return False, (r.stderr or r.stdout).strip() or 'img2pdf failed'


@app.post('/scan/finish')
def scan_finish():
    global _scan
    dest = request.form.get('dest', 'pdf')

    with _scan_lock:
        if not _scan or not _scan['pages']:
            return redirect(url_for('scan_index', **_lt()))
        tmpdir = _scan['tmpdir']
        pages = list(_scan['pages'])
        # Detach the session so a slow img2pdf doesn't block /scan/cancel.
        _scan = None

    pdf_path = os.path.join(tmpdir, 'scan.pdf')
    ok, err = _combine_pdf(pages, pdf_path)
    if not ok:
        shutil.rmtree(tmpdir, ignore_errors=True)
        flash_msg('err', 'scan_error', err=err[:200])
        return redirect(url_for('scan_index', **_lt()))

    n = len(pages)
    if dest == 'print':
        ok, err = do_print(pdf_path, 1, 'A4')
        shutil.rmtree(tmpdir, ignore_errors=True)
        if ok:
            key = 'scan_printed_one' if n == 1 else 'scan_printed_many'
            flash_msg('ok', key, n=n)
        else:
            flash_msg('err', 'error', err=err)
        return redirect(url_for('scan_index', **_lt()))

    # Download the PDF. send_file streams, so we can't rmtree until the
    # response is fully written — use call_on_close.
    resp = send_file(
        pdf_path,
        mimetype='application/pdf',
        as_attachment=True,
        download_name='scan.pdf',
    )
    resp.call_on_close(lambda: shutil.rmtree(tmpdir, ignore_errors=True))
    return resp


@app.post('/scan/cancel')
def scan_cancel():
    global _scan
    with _scan_lock:
        if _scan is not None:
            shutil.rmtree(_scan['tmpdir'], ignore_errors=True)
            _scan = None
    flash_msg('ok', 'scan_cancelled')
    return redirect(url_for('scan_index', **_lt()))


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
