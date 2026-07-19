from flask import Flask, request
import subprocess, tempfile, os, shutil

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024

# Doc formats need LibreOffice to convert to PDF before CUPS can print them.
DOC_EXTS = {'.docx', '.odt', '.doc', '.rtf'}
IMG_EXTS = {'.jpg', '.jpeg', '.png', '.gif', '.tiff', '.bmp'}
ALLOWED = {'.pdf', '.txt'} | IMG_EXTS | DOC_EXTS
PAGE_SIZES = ['A4', 'Letter', 'Legal', 'A5', 'Executive']

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
    },
}

PAGE_TMPL = """<!DOCTYPE html>
<html lang="{lang}" class="{theme_class}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
  /* Dark theme = default. Light theme applied via <html class="light">. */
  :root {{
    --fs: clamp(1rem, 0.9rem + 0.6vw, 1.25rem);
    --bg: #1a1a1a;
    --fg: #e5e5e5;
    --muted: #999;
    --border: #333;
    --input-bg: #232323;
    --btn-bg: #2a2a2a;
    --btn-bg-hover: #3a3a3a;
    --ok-bg: #14532d;
    --ok-fg: #86efac;
    --err-bg: #7f1d1d;
    --err-fg: #fca5a5;
  }}
  :root.light {{
    --bg: #fafafa;
    --fg: #1a1a1a;
    --muted: #666;
    --border: #d0d0d0;
    --input-bg: #ffffff;
    --btn-bg: #e5e7eb;
    --btn-bg-hover: #d1d5db;
    --ok-bg: #dcfce7;
    --ok-fg: #15803d;
    --err-bg: #fee2e2;
    --err-fg: #b91c1c;
  }}
  * {{ box-sizing: border-box; }}
  html, body {{ margin: 0; padding: 0; }}
  body {{
    font-family: system-ui, -apple-system, sans-serif;
    font-size: var(--fs);
    background: var(--bg);
    color: var(--fg);
    line-height: 1.5;
    min-height: 100vh;
    display: flex;
    justify-content: center;
    padding: clamp(1rem, 4vw, 2.5rem);
  }}
  main {{
    width: 100%;
    max-width: 32rem;
    position: relative;
  }}
  .toggles {{
    position: absolute;
    top: 0;
    right: 0;
    display: flex;
    gap: .35rem;
  }}
  .toggle {{
    font-size: .85em;
    font-weight: 600;
    text-decoration: none;
    color: var(--muted);
    padding: .4rem .7rem;
    border: 1px solid var(--border);
    border-radius: .4rem;
    background: var(--input-bg);
  }}
  .toggle:hover {{ background: var(--btn-bg); }}
  h1 {{
    font-size: clamp(1.5rem, 1.2rem + 1.5vw, 2rem);
    margin: 0 0 1.5rem;
    padding-right: 6.5rem;
  }}
  form {{
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }}
  label {{
    display: flex;
    flex-direction: column;
    gap: .35rem;
    font-weight: 500;
  }}
  input[type=file], input[type=number], select {{
    font: inherit;
    padding: .6rem .75rem;
    border: 1px solid var(--border);
    border-radius: .5rem;
    background: var(--input-bg);
    color: var(--fg);
    width: 100%;
  }}
  input[type=file] {{ padding: .5rem; }}
  button {{
    font: inherit;
    font-weight: 600;
    padding: .8rem 1.5rem;
    border: 1px solid var(--border);
    border-radius: .5rem;
    background: var(--btn-bg);
    color: var(--fg);
    cursor: pointer;
    min-height: 48px;
  }}
  button:hover {{ background: var(--btn-bg-hover); }}
  button:active {{ transform: scale(.98); }}
  .msg {{
    padding: .75rem 1rem;
    border-radius: .5rem;
    margin-top: 1rem;
  }}
  .ok {{ background: var(--ok-bg); color: var(--ok-fg); }}
  .err {{ background: var(--err-bg); color: var(--err-fg); }}
</style>
</head>
<body>
<main>
  <div class=toggles>
    <a class=toggle href="?lang={other_lang}&theme={theme}">{switch_to}</a>
    <a class=toggle href="?lang={lang}&theme={other_theme}">{theme_label}</a>
  </div>
  <h1>{heading}</h1>
  <form method=post enctype=multipart/form-data action="/print?lang={lang}&theme={theme}">
    <label>
      {file}
      <input type=file name=file required accept=".pdf,.txt,.docx,.odt,.doc,.rtf,.jpg,.jpeg,.png,.gif,.tiff,.bmp">
    </label>
    <label>
      {copies}
      <input type=number name=copies value=1 min=1 max=50>
    </label>
    <label>
      {paper}
      <select name=media>
        {size_options}
      </select>
    </label>
    <button type=submit>{send}</button>
  </form>
  {msg}
</main>
</body>
</html>"""


def pick_lang():
    lang = request.args.get('lang', 'en')
    return lang if lang in STRINGS else 'en'


def pick_theme():
    theme = request.args.get('theme', 'dark')
    return theme if theme in ('dark', 'light') else 'dark'


def render(msg=''):
    lang = pick_lang()
    theme = pick_theme()
    s = STRINGS[lang]
    other_lang = 'fr' if lang == 'en' else 'en'
    other_theme = 'light' if theme == 'dark' else 'dark'
    theme_label = s['theme_to_light'] if theme == 'dark' else s['theme_to_dark']
    size_options = ''.join(
        f'<option value="{sz}"{" selected" if sz == "A4" else ""}>{sz}</option>'
        for sz in PAGE_SIZES
    )
    return PAGE_TMPL.format(
        lang=lang,
        other_lang=other_lang,
        theme=theme,
        other_theme=other_theme,
        theme_class='light' if theme == 'light' else '',
        theme_label=theme_label,
        size_options=size_options,
        msg=msg,
        **s,
    )


def msg(kind, key, **kwargs):
    s = STRINGS[pick_lang()]
    text = s[key].format(**kwargs) if kwargs else s[key]
    return f'<p class="msg {kind}">{text}</p>'


@app.get('/')
def index():
    return render()


@app.post('/print')
def print_file():
    f = request.files.get('file')
    if not f or not f.filename:
        return render(msg('err', 'no_file'))

    ext = os.path.splitext(f.filename)[1].lower()
    if ext not in ALLOWED:
        return render(msg('err', 'bad_ext', ext=ext))

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
                return render(msg('err', 'error', err=err))
        else:
            print_path = upload

        cmd = ['lp', '-n', str(copies), '-o', f'media={media}', print_path]
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode == 0:
            key = 'sent_one' if copies == 1 else 'sent_many'
            return render(msg('ok', key, n=copies))
        return render(msg('err', 'error', err=r.stderr.strip() or r.stdout.strip()))
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
