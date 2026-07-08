from flask import Flask
import os

app = Flask(__name__)

@app.route("/")
def home():
    return "Welcome to ECS", 200

@app.route("/health")
def health():
    return {"status": "healthy"}, 200

@app.route("/config")
def config():
    return {
        "APP_NAME": os.getenv("APP_NAME", "Not Configured"),
        "DB_HOST": os.getenv("DB_HOST", "Not Configured"),
        "API_KEY": "Configured" if os.getenv("API_KEY") else "Not Configured",
        "DB_PASSWORD": "Configured" if os.getenv("DB_PASSWORD") else "Not Configured"
    }, 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
