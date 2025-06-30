from flask import Flask, request, send_from_directory, render_template_string, redirect, url_for
import os

UPLOAD_BASE = "/workspace/usu/data"

app = Flask(__name__)

HTML = """
<!DOCTYPE html>
<html lang="de">
<head><meta charset="UTF-8"><title>Datei-Transfer</title></head>
<body>
  <h1>📁 Datei-Transfer: {{ user }}</h1>
  <h2>🔼 Upload</h2>
  <form action="{{ url_for('upload', user=user) }}" method="post" enctype="multipart/form-data">
    <input type="file" name="file">
    <button type="submit">Hochladen</button>
  </form>
  <h2>🔽 Dateien</h2>
  <ul>
    {% for file in files %}
      <li><a href="{{ url_for('download_file', user=user, filename=file) }}">{{ file }}</a></li>
    {% endfor %}
  </ul>
</body>
</html>
"""

def get_user_dir(user):
    user_dir = os.path.join(UPLOAD_BASE, user)
    os.makedirs(user_dir, exist_ok=True)
    return user_dir

@app.route("/<user>/transfer/")
def index(user):
    user_dir = get_user_dir(user)
    files = sorted(os.listdir(user_dir))
    return render_template_string(HTML, files=files, user=user)

@app.route("/<user>/transfer/upload", methods=["POST"])
def upload(user):
    user_dir = get_user_dir(user)
    if "file" not in request.files:
        return "Keine Datei hochgeladen", 400
    file = request.files["file"]
    if file.filename == "":
        return "Keine Datei ausgewählt", 400
    file.save(os.path.join(user_dir, file.filename))
    return redirect(url_for("index", user=user))

@app.route("/<user>/transfer/<path:filename>")
def download_file(user, filename):
    user_dir = get_user_dir(user)
    return send_from_directory(user_dir, filename)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
