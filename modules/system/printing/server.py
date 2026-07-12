from flask import Flask, request
import subprocess, tempfile, os

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024

ALLOWED = {'.pdf', '.jpg', '.jpeg', '.png', '.gif', '.tiff', '.bmp'}
PAGE_SIZES = ['A4', 'Letter', 'Legal', 'A5', 'Executive']

PAGE_TMPL = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Print</title>
<style>
  :root {{
    --fs: clamp(1rem, 0.9rem + 0.6vw, 1.25rem);
    --bg: #fafafa;
    --fg: #1a1a1a;
    --border: #d0d0d0;
    --accent: #2563eb;
    --ok: #15803d;
    --err: #b91c1c;
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
  }}
  h1 {{
    font-size: clamp(1.5rem, 1.2rem + 1.5vw, 2rem);
    margin: 0 0 1.5rem;
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
    background: white;
    width: 100%;
  }}
  input[type=file] {{ padding: .5rem; }}
  .row-check {{
    flex-direction: row;
    align-items: center;
    gap: .6rem;
    font-weight: 500;
  }}
  input[type=checkbox] {{
    width: 1.15rem;
    height: 1.15rem;
    margin: 0;
    accent-color: var(--accent);
  }}
  button {{
    font: inherit;
    font-weight: 600;
    padding: .8rem 1.5rem;
    border: none;
    border-radius: .5rem;
    background: var(--accent);
    color: white;
    cursor: pointer;
    min-height: 48px;
  }}
  button:active {{ transform: scale(.98); }}
  .note {{
    font-size: .85em;
    color: #666;
    margin-top: -.75rem;
  }}
  .msg {{
    padding: .75rem 1rem;
    border-radius: .5rem;
    margin-top: 1rem;
  }}
  .ok {{ background: #dcfce7; color: var(--ok); }}
  .err {{ background: #fee2e2; color: var(--err); }}
</style>
</head>
<body>
<main>
  <h1>Print a document</h1>
  <form method=post enctype=multipart/form-data action=/print>
    <label>
      File
      <input type=file name=file required accept=".pdf,.jpg,.jpeg,.png,.gif,.tiff,.bmp">
    </label>
    <label>
      Copies
      <input type=number name=copies value=1 min=1 max=50>
    </label>
    <label>
      Paper size
      <select name=media>
        {size_options}
      </select>
    </label>
    <label class=row-check>
      <input type=checkbox name=draft value=1>
      Toner-save (draft quality)
    </label>
    <button type=submit>Send to printer</button>
    <p class=note>Canon MF3010 is a monochrome laser — everything prints black &amp; white.</p>
  </form>
  {msg}
</main>
</body>
</html>"""


def render(msg=''):
    size_options = ''.join(
        f'<option value="{s}"{" selected" if s == "A4" else ""}>{s}</option>'
        for s in PAGE_SIZES
    )
    return PAGE_TMPL.format(size_options=size_options, msg=msg)


@app.get('/')
def index():
    return render()


@app.post('/print')
def print_file():
    f = request.files.get('file')
    if not f or not f.filename:
        return render('<p class="msg err">No file selected.</p>')

    ext = os.path.splitext(f.filename)[1].lower()
    if ext not in ALLOWED:
        return render(f'<p class="msg err">Unsupported format: {ext!r}. Use PDF or an image.</p>')

    try:
        copies = max(1, min(50, int(request.form.get('copies', '1'))))
    except ValueError:
        copies = 1

    media = request.form.get('media', 'A4')
    if media not in PAGE_SIZES:
        media = 'A4'

    draft = request.form.get('draft') == '1'

    with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp:
        f.save(tmp.name)
        path = tmp.name

    try:
        cmd = ['lp', '-n', str(copies), '-o', f'media={media}']
        if draft:
            cmd += ['-o', 'CNDraftMode=True']
        cmd.append(path)
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode == 0:
            return render(f'<p class="msg ok">Sent {copies} cop{"y" if copies == 1 else "ies"} to printer.</p>')
        return render(f'<p class="msg err">Print error: {r.stderr.strip() or r.stdout.strip()}</p>')
    finally:
        os.unlink(path)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
