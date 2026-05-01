import os

from dotenv import load_dotenv
from flask import Flask, jsonify, request

load_dotenv()

app = Flask(__name__)

ACCOUNT_ID = os.getenv("ACCOUNT_ID")
SIGN_KEY = os.getenv("SIGN_KEY")
SECRET_KEY = os.getenv("SECRET_KEY")
VECTOR = os.getenv("VECTOR")
API_VERSION = os.getenv("API_VERSION")
BASE_URL = os.getenv("BASE_URL")


@app.get("/get_full_iccid_details")
def get_full_iccid_details():
    """Keep existing endpoint contract and expose runtime config health."""
    iccid = request.args.get("iccid")
    return jsonify(
        {
            "iccid": iccid,
            "api_version": API_VERSION,
            "base_url": BASE_URL,
            "config_loaded": all(
                [ACCOUNT_ID, SIGN_KEY, SECRET_KEY, VECTOR, API_VERSION, BASE_URL]
            ),
        }
    )


@app.get("/health")
def health():
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
